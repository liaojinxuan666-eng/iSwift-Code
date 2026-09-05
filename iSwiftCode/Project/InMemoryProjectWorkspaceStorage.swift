import Foundation

/// Thread-safe ephemeral workspace storage.
///
/// This backend is useful for scratch projects, previews, tests, and the current
/// single-editor migration. Persistent projects use a different
/// `ProjectWorkspaceStorage` implementation without changing the workspace API.
final class InMemoryProjectWorkspaceStorage: ProjectWorkspaceStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var files: [WorkspacePath: Data]

    init(files: [WorkspacePath: Data] = [:]) {
        self.files = files
    }

    func listFiles() throws -> [WorkspacePath] {
        lock.lock()
        defer { lock.unlock() }
        return files.keys.sorted()
    }

    func readFile(at path: WorkspacePath) throws -> Data {
        lock.lock()
        defer { lock.unlock() }

        guard let data = files[path] else {
            throw CocoaError(.fileNoSuchFile)
        }
        return data
    }

    func writeFile(_ data: Data, at path: WorkspacePath) throws {
        lock.lock()
        defer { lock.unlock() }
        files[path] = data
    }

    func deleteFile(at path: WorkspacePath) throws {
        lock.lock()
        defer { lock.unlock() }

        guard files.removeValue(forKey: path) != nil else {
            throw CocoaError(.fileNoSuchFile)
        }
    }

    func moveFile(from sourcePath: WorkspacePath, to destinationPath: WorkspacePath) throws {
        lock.lock()
        defer { lock.unlock() }

        guard let data = files.removeValue(forKey: sourcePath) else {
            throw CocoaError(.fileNoSuchFile)
        }
        files[destinationPath] = data
    }
}
