import Foundation

protocol ProjectWorkspaceStorage: Sendable {
    func listFiles() throws -> [WorkspacePath]
    func readFile(at path: WorkspacePath) throws -> Data
    func writeFile(_ data: Data, at path: WorkspacePath) throws
    func deleteFile(at path: WorkspacePath) throws
    func moveFile(from sourcePath: WorkspacePath, to destinationPath: WorkspacePath) throws
}

/// Filesystem-backed project storage rooted inside one directory.
///
/// All callers use validated `WorkspacePath` values, and this backend performs a
/// second root-containment check before touching the filesystem.
struct DirectoryProjectWorkspaceStorage: ProjectWorkspaceStorage, @unchecked Sendable {
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

    func listFiles() throws -> [WorkspacePath] {
        guard fileManager.fileExists(atPath: rootURL.path) else {
            return []
        }

        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var result: [WorkspacePath] = []

        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true else { continue }

            let relative = try relativePath(for: url)
            result.append(try WorkspacePath(relative))
        }

        return result.sorted()
    }

    func readFile(at path: WorkspacePath) throws -> Data {
        try Data(contentsOf: resolvedURL(for: path))
    }

    func writeFile(_ data: Data, at path: WorkspacePath) throws {
        let destination = try resolvedURL(for: path)
        try fileManager.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: destination, options: .atomic)
    }

    func deleteFile(at path: WorkspacePath) throws {
        try fileManager.removeItem(at: resolvedURL(for: path))
    }

    func moveFile(from sourcePath: WorkspacePath, to destinationPath: WorkspacePath) throws {
        let source = try resolvedURL(for: sourcePath)
        let destination = try resolvedURL(for: destinationPath)

        try fileManager.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try fileManager.moveItem(at: source, to: destination)
    }

    private func resolvedURL(for path: WorkspacePath) throws -> URL {
        let candidate = rootURL
            .appendingPathComponent(path.value, isDirectory: false)
            .standardizedFileURL

        let rootPath = rootURL.path.hasSuffix("/") ? rootURL.path : rootURL.path + "/"
        guard candidate.path.hasPrefix(rootPath) else {
            throw WorkspacePathError.absolutePath
        }

        return candidate
    }

    private func relativePath(for fileURL: URL) throws -> String {
        let rootPath = rootURL.path.hasSuffix("/") ? rootURL.path : rootURL.path + "/"
        let filePath = fileURL.standardizedFileURL.path

        guard filePath.hasPrefix(rootPath) else {
            throw WorkspacePathError.absolutePath
        }

        return String(filePath.dropFirst(rootPath.count))
    }
}
