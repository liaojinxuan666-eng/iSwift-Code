import Foundation

/// Bridges the generic project workspace into the permission-checked plugin Host
/// Services API. Plugins still receive only `PluginHostServices`; they never
/// receive a `ProjectWorkspace` instance directly.
struct ProjectWorkspacePluginBackend: PluginWorkspaceHostBackend, Sendable {
    let workspace: ProjectWorkspace

    func listFiles() throws -> [String] {
        try workspace.listFiles().map(\.value)
    }

    func readFile(at path: String) throws -> Data {
        try workspace.readFile(at: WorkspacePath(path))
    }

    func writeFile(_ data: Data, at path: String) throws {
        try workspace.writeFile(data, at: WorkspacePath(path))
    }

    func deleteFile(at path: String) throws {
        try workspace.deleteFile(at: WorkspacePath(path))
    }

    func moveFile(from sourcePath: String, to destinationPath: String) throws {
        try workspace.moveFile(
            from: WorkspacePath(sourcePath),
            to: WorkspacePath(destinationPath)
        )
    }
}
