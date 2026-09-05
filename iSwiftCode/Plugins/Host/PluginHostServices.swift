import Foundation

enum PluginHostServiceError: Error, Equatable, Sendable {
    case serviceUnavailable(String)
}

extension PluginHostServiceError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .serviceUnavailable(let service):
            return "Plugin host service '\(service)' is unavailable."
        }
    }
}

struct PluginNetworkRequest: Equatable, Sendable {
    let method: String
    let url: URL
    let headers: [String: String]
    let body: Data?

    init(
        method: String = "GET",
        url: URL,
        headers: [String: String] = [:],
        body: Data? = nil
    ) {
        self.method = method
        self.url = url
        self.headers = headers
        self.body = body
    }
}

struct PluginNetworkResponse: Equatable, Sendable {
    let statusCode: Int
    let headers: [String: String]
    let body: Data

    init(statusCode: Int, headers: [String: String] = [:], body: Data = Data()) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
    }
}

struct PluginUserFile: Equatable, Sendable {
    let suggestedName: String
    let data: Data
}

struct PluginBuildArtifactFile: Equatable, Sendable {
    let path: String
    let data: Data
}

protocol PluginWorkspaceHostBackend: Sendable {
    func listFiles() throws -> [String]
    func readFile(at path: String) throws -> Data
    func writeFile(_ data: Data, at path: String) throws
    func deleteFile(at path: String) throws
    func moveFile(from sourcePath: String, to destinationPath: String) throws
}

protocol PluginNetworkHostBackend: Sendable {
    func send(_ request: PluginNetworkRequest) async throws -> PluginNetworkResponse
}

protocol PluginCredentialHostBackend: Sendable {
    func data(forKey key: String) throws -> Data?
    func setData(_ data: Data, forKey key: String) throws
    func removeData(forKey key: String) throws
}

protocol PluginClipboardHostBackend: Sendable {
    func readText() throws -> String?
    func writeText(_ text: String?) throws
}

protocol PluginUserFilesHostBackend: Sendable {
    func importFile() async throws -> PluginUserFile?
    func exportFile(_ file: PluginUserFile) async throws
}

protocol PluginBuildArtifactsHostBackend: Sendable {
    func listArtifacts() throws -> [String]
    func readArtifact(at path: String) throws -> Data
    func writeArtifact(_ artifact: PluginBuildArtifactFile) throws
}

protocol PluginExternalURLHostBackend: Sendable {
    func open(_ url: URL) async throws
}

struct PluginHostServiceBackends: Sendable {
    let workspace: (any PluginWorkspaceHostBackend)?
    let network: (any PluginNetworkHostBackend)?
    let credentials: (any PluginCredentialHostBackend)?
    let clipboard: (any PluginClipboardHostBackend)?
    let userFiles: (any PluginUserFilesHostBackend)?
    let buildArtifacts: (any PluginBuildArtifactsHostBackend)?
    let externalURL: (any PluginExternalURLHostBackend)?

    init(
        workspace: (any PluginWorkspaceHostBackend)? = nil,
        network: (any PluginNetworkHostBackend)? = nil,
        credentials: (any PluginCredentialHostBackend)? = nil,
        clipboard: (any PluginClipboardHostBackend)? = nil,
        userFiles: (any PluginUserFilesHostBackend)? = nil,
        buildArtifacts: (any PluginBuildArtifactsHostBackend)? = nil,
        externalURL: (any PluginExternalURLHostBackend)? = nil
    ) {
        self.workspace = workspace
        self.network = network
        self.credentials = credentials
        self.clipboard = clipboard
        self.userFiles = userFiles
        self.buildArtifacts = buildArtifacts
        self.externalURL = externalURL
    }

    static let empty = PluginHostServiceBackends()
}

/// Permission-checked facade exposed to plugins.
///
/// Backends are supplied by iSwift Code. Plugins cannot obtain a backend
/// directly through this API, so permission checks happen again at every host
/// service call instead of only once during activation.
struct PluginHostServices: Sendable {
    let pluginIdentifier: String
    let grantedPermissions: Set<PluginPermission>
    private let backends: PluginHostServiceBackends

    init(
        pluginIdentifier: String,
        grantedPermissions: Set<PluginPermission>,
        backends: PluginHostServiceBackends = .empty
    ) {
        self.pluginIdentifier = pluginIdentifier
        self.grantedPermissions = grantedPermissions
        self.backends = backends
    }

    func hasPermission(_ permission: PluginPermission) -> Bool {
        grantedPermissions.contains(permission)
    }

    func listWorkspaceFiles() throws -> [String] {
        try require(.workspaceRead)
        guard let backend = backends.workspace else {
            throw PluginHostServiceError.serviceUnavailable("workspace")
        }
        return try backend.listFiles()
    }

    func readWorkspaceFile(at path: String) throws -> Data {
        try require(.workspaceRead)
        guard let backend = backends.workspace else {
            throw PluginHostServiceError.serviceUnavailable("workspace")
        }
        return try backend.readFile(at: path)
    }

    func writeWorkspaceFile(_ data: Data, at path: String) throws {
        try require(.workspaceWrite)
        guard let backend = backends.workspace else {
            throw PluginHostServiceError.serviceUnavailable("workspace")
        }
        try backend.writeFile(data, at: path)
    }

    func deleteWorkspaceFile(at path: String) throws {
        try require(.workspaceWrite)
        guard let backend = backends.workspace else {
            throw PluginHostServiceError.serviceUnavailable("workspace")
        }
        try backend.deleteFile(at: path)
    }

    func moveWorkspaceFile(from sourcePath: String, to destinationPath: String) throws {
        try require(.workspaceWrite)
        guard let backend = backends.workspace else {
            throw PluginHostServiceError.serviceUnavailable("workspace")
        }
        try backend.moveFile(from: sourcePath, to: destinationPath)
    }

    func sendNetworkRequest(_ request: PluginNetworkRequest) async throws -> PluginNetworkResponse {
        try require(.network)
        guard let backend = backends.network else {
            throw PluginHostServiceError.serviceUnavailable("network")
        }
        return try await backend.send(request)
    }

    func readCredential(forKey key: String) throws -> Data? {
        try require(.credentials)
        guard let backend = backends.credentials else {
            throw PluginHostServiceError.serviceUnavailable("credentials")
        }
        return try backend.data(forKey: key)
    }

    func writeCredential(_ data: Data, forKey key: String) throws {
        try require(.credentials)
        guard let backend = backends.credentials else {
            throw PluginHostServiceError.serviceUnavailable("credentials")
        }
        try backend.setData(data, forKey: key)
    }

    func removeCredential(forKey key: String) throws {
        try require(.credentials)
        guard let backend = backends.credentials else {
            throw PluginHostServiceError.serviceUnavailable("credentials")
        }
        try backend.removeData(forKey: key)
    }

    func readClipboardText() throws -> String? {
        try require(.clipboard)
        guard let backend = backends.clipboard else {
            throw PluginHostServiceError.serviceUnavailable("clipboard")
        }
        return try backend.readText()
    }

    func writeClipboardText(_ text: String?) throws {
        try require(.clipboard)
        guard let backend = backends.clipboard else {
            throw PluginHostServiceError.serviceUnavailable("clipboard")
        }
        try backend.writeText(text)
    }

    func importUserFile() async throws -> PluginUserFile? {
        try require(.userFiles)
        guard let backend = backends.userFiles else {
            throw PluginHostServiceError.serviceUnavailable("userFiles")
        }
        return try await backend.importFile()
    }

    func exportUserFile(_ file: PluginUserFile) async throws {
        try require(.userFiles)
        guard let backend = backends.userFiles else {
            throw PluginHostServiceError.serviceUnavailable("userFiles")
        }
        try await backend.exportFile(file)
    }

    func listBuildArtifacts() throws -> [String] {
        try require(.buildArtifacts)
        guard let backend = backends.buildArtifacts else {
            throw PluginHostServiceError.serviceUnavailable("buildArtifacts")
        }
        return try backend.listArtifacts()
    }

    func readBuildArtifact(at path: String) throws -> Data {
        try require(.buildArtifacts)
        guard let backend = backends.buildArtifacts else {
            throw PluginHostServiceError.serviceUnavailable("buildArtifacts")
        }
        return try backend.readArtifact(at: path)
    }

    func writeBuildArtifact(_ artifact: PluginBuildArtifactFile) throws {
        try require(.buildArtifacts)
        guard let backend = backends.buildArtifacts else {
            throw PluginHostServiceError.serviceUnavailable("buildArtifacts")
        }
        try backend.writeArtifact(artifact)
    }

    func openExternalURL(_ url: URL) async throws {
        try require(.openExternalURL)
        guard let backend = backends.externalURL else {
            throw PluginHostServiceError.serviceUnavailable("openExternalURL")
        }
        try await backend.open(url)
    }

    private func require(_ permission: PluginPermission) throws {
        guard grantedPermissions.contains(permission) else {
            throw PluginHostContextError.permissionDenied(permission)
        }
    }
}
