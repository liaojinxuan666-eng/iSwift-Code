import Foundation

enum ProjectStoreError: Error, Equatable, Sendable {
    case projectAlreadyExists(String)
    case projectNotFound(String)
    case descriptorMissing(String)
    case descriptorIdentifierMismatch(expected: String, found: String)
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
