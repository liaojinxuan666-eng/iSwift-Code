import Foundation

enum ProjectWorkspaceError: Error, Equatable, Sendable {
    case invalidUTF8(WorkspacePath)
    case entryFileNotConfigured
    case entryFileMissing(WorkspacePath)
    case descriptorIdentifierMismatch(expected: String, found: String)
}

extension ProjectWorkspaceError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidUTF8(let path):
            return "Workspace file '\(path.value)' is not valid UTF-8 text."
        case .entryFileNotConfigured:
            return "Project does not define an entry file."
        case .entryFileMissing(let path):
            return "Configured entry file '\(path.value)' does not exist."
        case .descriptorIdentifierMismatch(let expected, let found):
            return "Replacement descriptor identifier '\(found)' does not match workspace identifier '\(expected)'."
        }
    }
}

struct ProjectWorkspaceFile: Equatable, Sendable {
    let path: WorkspacePath
    let data: Data

    var text: String? {
        String(data: data, encoding: .utf8)
    }
}

struct ProjectWorkspaceSnapshot: Equatable, Sendable {
    let descriptor: ProjectDescriptor
    let files: [ProjectWorkspaceFile]

    func file(at path: WorkspacePath) -> ProjectWorkspaceFile? {
        files.first { $0.path == path }
    }
}

/// Generic multi-file project workspace.
///
/// The workspace owns project-relative path semantics and delegates persistence
/// to a replaceable storage backend. It has no knowledge of Swift, Clang,
/// Codex-like providers, UI, or a specific future app.
struct ProjectWorkspace: Sendable {
    let descriptor: ProjectDescriptor
    private let storage: any ProjectWorkspaceStorage

    init(
        descriptor: ProjectDescriptor,
        storage: any ProjectWorkspaceStorage
    ) throws {
        try descriptor.validate()
        self.descriptor = descriptor
        self.storage = storage
    }

    func replacingDescriptor(_ replacement: ProjectDescriptor) throws -> ProjectWorkspace {
        guard replacement.identifier == descriptor.identifier else {
            throw ProjectWorkspaceError.descriptorIdentifierMismatch(
                expected: descriptor.identifier,
                found: replacement.identifier
            )
        }

        return try ProjectWorkspace(
            descriptor: replacement,
            storage: storage
        )
    }

    func listFiles() throws -> [WorkspacePath] {
        try storage.listFiles().sorted()
    }

    func contains(_ path: WorkspacePath) throws -> Bool {
        try listFiles().contains(path)
    }

    func readFile(at path: WorkspacePath) throws -> Data {
        try storage.readFile(at: path)
    }

    func readTextFile(at path: WorkspacePath) throws -> String {
        let data = try readFile(at: path)
        guard let text = String(data: data, encoding: .utf8) else {
            throw ProjectWorkspaceError.invalidUTF8(path)
        }
        return text
    }

    func writeFile(_ data: Data, at path: WorkspacePath) throws {
        try storage.writeFile(data, at: path)
    }

    func writeTextFile(_ text: String, at path: WorkspacePath) throws {
        try writeFile(Data(text.utf8), at: path)
    }

    func deleteFile(at path: WorkspacePath) throws {
        try storage.deleteFile(at: path)
    }

    func moveFile(from sourcePath: WorkspacePath, to destinationPath: WorkspacePath) throws {
        try storage.moveFile(from: sourcePath, to: destinationPath)
    }

    func entryFile() throws -> ProjectWorkspaceFile {
        guard let path = descriptor.entryFilePath else {
            throw ProjectWorkspaceError.entryFileNotConfigured
        }
        guard try contains(path) else {
            throw ProjectWorkspaceError.entryFileMissing(path)
        }
        return ProjectWorkspaceFile(path: path, data: try readFile(at: path))
    }

    func snapshot() throws -> ProjectWorkspaceSnapshot {
        let paths = try listFiles()
        let files = try paths.map { path in
            ProjectWorkspaceFile(path: path, data: try readFile(at: path))
        }

        return ProjectWorkspaceSnapshot(
            descriptor: descriptor,
            files: files
        )
    }
}
