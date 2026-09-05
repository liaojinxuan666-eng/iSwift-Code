import Foundation

enum ProjectStoreError: Error, Equatable, Sendable {
    case projectAlreadyExists(String)
    case projectNotFound(String)
    case descriptorMissing(String)
    case descriptorIdentifierMismatch(expected: String, found: String)
    case fileNotFound(WorkspacePath)
    case fileAlreadyExists(WorkspacePath)
    case entryFileNotFound(WorkspacePath)
    case replacementEntryMatchesDeletedFile(WorkspacePath)
}

extension ProjectStoreError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .projectAlreadyExists(let identifier):
            return "Project '\(identifier)' already exists."
        case .projectNotFound(let identifier):
            return "Project '\(identifier)' does not exist."
        case .descriptorMissing(let identifier):
            return "Project '\(identifier)' is missing its descriptor."
        case .descriptorIdentifierMismatch(let expected, let found):
            return "Project descriptor identifier '\(found)' does not match directory identifier '\(expected)'."
        case .fileNotFound(let path):
            return "Project file '\(path.value)' does not exist."
        case .fileAlreadyExists(let path):
            return "Project file '\(path.value)' already exists."
        case .entryFileNotFound(let path):
            return "Entry file '\(path.value)' does not exist in the project."
        case .replacementEntryMatchesDeletedFile(let path):
            return "Deleted file '\(path.value)' cannot also be its replacement entry file."
        }
    }
}

/// Persistent project catalog.
///
/// Each project lives in its own directory:
///
/// Projects/<identifier>/
/// ├── .iswift/project.json
/// └── project files...
///
/// `.iswift` is hidden from `DirectoryProjectWorkspaceStorage` because that
/// storage skips hidden files. Project metadata therefore never appears as a
/// normal source/resource file or leaks into plugin workspace listings.
struct ProjectStore: @unchecked Sendable {
    static let metadataDirectoryName = ".iswift"
    static let descriptorFileName = "project.json"

    let rootURL: URL
    private let fileManager: FileManager

    init(
        rootURL: URL,
        fileManager: FileManager = .default,
        createIfNeeded: Bool = true
    ) throws {
        self.rootURL = rootURL.standardizedFileURL
        self.fileManager = fileManager

        if createIfNeeded {
            try fileManager.createDirectory(
                at: self.rootURL,
                withIntermediateDirectories: true
            )
        }
    }

    static func applicationSupport(
        fileManager: FileManager = .default
    ) throws -> ProjectStore {
        let applicationSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let root = applicationSupport
            .appendingPathComponent("iSwift Code", isDirectory: true)
            .appendingPathComponent("Projects", isDirectory: true)

        return try ProjectStore(
            rootURL: root,
            fileManager: fileManager,
            createIfNeeded: true
        )
    }

    func projectExists(identifier: String) throws -> Bool {
        try validateIdentifier(identifier)

        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(
            atPath: projectRootURL(identifier: identifier).path,
            isDirectory: &isDirectory
        )
        return exists && isDirectory.boolValue
    }

    func createProject(
        descriptor: ProjectDescriptor,
        initialFiles: [WorkspacePath: Data] = [:]
    ) throws -> ProjectWorkspace {
        try descriptor.validate()

        let projectRoot = projectRootURL(identifier: descriptor.identifier)
        guard !fileManager.fileExists(atPath: projectRoot.path) else {
            throw ProjectStoreError.projectAlreadyExists(descriptor.identifier)
        }

        do {
            try fileManager.createDirectory(
                at: projectRoot,
                withIntermediateDirectories: true
            )

            try writeDescriptor(descriptor, projectRoot: projectRoot)

            let storage = try DirectoryProjectWorkspaceStorage(
                rootURL: projectRoot,
                fileManager: fileManager,
                createIfNeeded: false
            )
            let workspace = try ProjectWorkspace(
                descriptor: descriptor,
                storage: storage
            )

            for (path, data) in initialFiles {
                try workspace.writeFile(data, at: path)
            }

            return workspace
        } catch {
            try? fileManager.removeItem(at: projectRoot)
            throw error
        }
    }

    func openProject(identifier: String) throws -> ProjectWorkspace {
        try validateIdentifier(identifier)

        let projectRoot = projectRootURL(identifier: identifier)

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(
            atPath: projectRoot.path,
            isDirectory: &isDirectory
        ), isDirectory.boolValue else {
            throw ProjectStoreError.projectNotFound(identifier)
        }

        let descriptor = try readDescriptor(
            identifier: identifier,
            projectRoot: projectRoot
        )

        let storage = try DirectoryProjectWorkspaceStorage(
            rootURL: projectRoot,
            fileManager: fileManager,
            createIfNeeded: false
        )

        return try ProjectWorkspace(
            descriptor: descriptor,
            storage: storage
        )
    }

    func openOrCreateProject(
        descriptor: ProjectDescriptor,
        initialFiles: [WorkspacePath: Data] = [:]
    ) throws -> ProjectWorkspace {
        try descriptor.validate()

        if try projectExists(identifier: descriptor.identifier) {
            return try openProject(identifier: descriptor.identifier)
        }

        return try createProject(
            descriptor: descriptor,
            initialFiles: initialFiles
        )
    }

    func saveDescriptor(_ descriptor: ProjectDescriptor) throws {
        try descriptor.validate()

        let projectRoot = projectRootURL(identifier: descriptor.identifier)

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(
            atPath: projectRoot.path,
            isDirectory: &isDirectory
        ), isDirectory.boolValue else {
            throw ProjectStoreError.projectNotFound(descriptor.identifier)
        }

        try writeDescriptor(descriptor, projectRoot: projectRoot)
    }

    /// Change only the project's entry-file metadata.
    ///
    /// Passing nil intentionally clears the entry-file selection.
    func setEntryFile(
        projectIdentifier: String,
        path: WorkspacePath?
    ) throws -> ProjectWorkspace {
        let workspace = try openProject(identifier: projectIdentifier)

        if let path, !(try workspace.contains(path)) {
            throw ProjectStoreError.entryFileNotFound(path)
        }

        let updatedDescriptor = workspace.descriptor.replacingEntryFilePath(path)
        try saveDescriptor(updatedDescriptor)

        return try workspace.replacingDescriptor(updatedDescriptor)
    }

    /// Rename a project file and keep descriptor metadata consistent.
    ///
    /// If the source is the current entry file, the descriptor is updated after
    /// the file move. If metadata persistence fails, the move is rolled back.
    func renameFile(
        projectIdentifier: String,
        from sourcePath: WorkspacePath,
        to destinationPath: WorkspacePath
    ) throws -> ProjectWorkspace {
        let workspace = try openProject(identifier: projectIdentifier)

        guard try workspace.contains(sourcePath) else {
            throw ProjectStoreError.fileNotFound(sourcePath)
        }
        guard !(try workspace.contains(destinationPath)) else {
            throw ProjectStoreError.fileAlreadyExists(destinationPath)
        }

        let oldDescriptor = workspace.descriptor
        let shouldUpdateEntry = oldDescriptor.entryFilePath == sourcePath
        let updatedDescriptor = shouldUpdateEntry
            ? oldDescriptor.replacingEntryFilePath(destinationPath)
            : oldDescriptor

        try workspace.moveFile(
            from: sourcePath,
            to: destinationPath
        )

        do {
            if shouldUpdateEntry {
                try saveDescriptor(updatedDescriptor)
            }
        } catch {
            try? workspace.moveFile(
                from: destinationPath,
                to: sourcePath
            )
            throw error
        }

        if shouldUpdateEntry {
            return try workspace.replacingDescriptor(updatedDescriptor)
        }
        return workspace
    }

    /// Delete a project file while keeping entry metadata valid.
    ///
    /// If the deleted file is the entry file, the caller supplies the new entry
    /// file or nil to clear it. File bytes are retained in memory until metadata
    /// persistence succeeds so a descriptor-write failure can restore the file.
    func deleteFile(
        projectIdentifier: String,
        at path: WorkspacePath,
        replacementEntryFile: WorkspacePath? = nil
    ) throws -> ProjectWorkspace {
        let workspace = try openProject(identifier: projectIdentifier)

        guard try workspace.contains(path) else {
            throw ProjectStoreError.fileNotFound(path)
        }

        let oldDescriptor = workspace.descriptor
        let isDeletingEntry = oldDescriptor.entryFilePath == path

        if isDeletingEntry, let replacementEntryFile {
            guard replacementEntryFile != path else {
                throw ProjectStoreError.replacementEntryMatchesDeletedFile(path)
            }
            guard try workspace.contains(replacementEntryFile) else {
                throw ProjectStoreError.entryFileNotFound(replacementEntryFile)
            }
        }

        let updatedDescriptor = isDeletingEntry
            ? oldDescriptor.replacingEntryFilePath(replacementEntryFile)
            : oldDescriptor

        let originalData = try workspace.readFile(at: path)
        try workspace.deleteFile(at: path)

        do {
            if isDeletingEntry {
                try saveDescriptor(updatedDescriptor)
            }
        } catch {
            try? workspace.writeFile(originalData, at: path)
            throw error
        }

        if isDeletingEntry {
            return try workspace.replacingDescriptor(updatedDescriptor)
        }
        return workspace
    }

    func listProjects() throws -> [ProjectDescriptor] {
        guard fileManager.fileExists(atPath: rootURL.path) else {
            return []
        }

        let urls = try fileManager.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        var descriptors: [ProjectDescriptor] = []

        for url in urls {
            let values = try url.resourceValues(forKeys: [.isDirectoryKey])
            guard values.isDirectory == true else { continue }

            let identifier = url.lastPathComponent
            try validateIdentifier(identifier)

            let descriptor = try readDescriptor(
                identifier: identifier,
                projectRoot: url
            )
            descriptors.append(descriptor)
        }

        return descriptors.sorted {
            if $0.displayName == $1.displayName {
                return $0.identifier < $1.identifier
            }
            return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    func deleteProject(identifier: String) throws {
        try validateIdentifier(identifier)

        let projectRoot = projectRootURL(identifier: identifier)
        guard fileManager.fileExists(atPath: projectRoot.path) else {
            throw ProjectStoreError.projectNotFound(identifier)
        }

        try fileManager.removeItem(at: projectRoot)
    }

    func projectRootURL(identifier: String) -> URL {
        rootURL
            .appendingPathComponent(identifier, isDirectory: true)
            .standardizedFileURL
    }

    private func validateIdentifier(_ identifier: String) throws {
        let descriptor = ProjectDescriptor(
            identifier: identifier,
            displayName: "Project"
        )
        try descriptor.validate()
    }

    private func metadataDirectoryURL(projectRoot: URL) -> URL {
        projectRoot.appendingPathComponent(
            Self.metadataDirectoryName,
            isDirectory: true
        )
    }

    private func descriptorURL(projectRoot: URL) -> URL {
        metadataDirectoryURL(projectRoot: projectRoot)
            .appendingPathComponent(Self.descriptorFileName)
    }

    private func writeDescriptor(
        _ descriptor: ProjectDescriptor,
        projectRoot: URL
    ) throws {
        let metadataDirectory = metadataDirectoryURL(projectRoot: projectRoot)

        try fileManager.createDirectory(
            at: metadataDirectory,
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(descriptor)

        try data.write(
            to: descriptorURL(projectRoot: projectRoot),
            options: .atomic
        )
    }

    private func readDescriptor(
        identifier: String,
        projectRoot: URL
    ) throws -> ProjectDescriptor {
        let url = descriptorURL(projectRoot: projectRoot)

        guard fileManager.fileExists(atPath: url.path) else {
            throw ProjectStoreError.descriptorMissing(identifier)
        }

        let data = try Data(contentsOf: url)
        let descriptor = try JSONDecoder().decode(
            ProjectDescriptor.self,
            from: data
        )

        try descriptor.validate()

        guard descriptor.identifier == identifier else {
            throw ProjectStoreError.descriptorIdentifierMismatch(
                expected: identifier,
                found: descriptor.identifier
            )
        }

        return descriptor
    }
}
