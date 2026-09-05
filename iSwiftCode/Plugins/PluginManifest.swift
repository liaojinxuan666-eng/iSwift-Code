import Foundation

enum PluginCapability: String, Codable, CaseIterable, Hashable, Sendable {
    case compiler
    case aiAssistant
    case editor
    case build
    case projectTemplate
    case runtime
    case formatter
    case languageServer
}

enum PluginExecutionMode: String, Codable, CaseIterable, Hashable, Sendable {
    /// Code that ships with iSwift Code and is linked/bundled with the app.
    case builtIn

    /// Portable plugin code intended to execute inside a WebAssembly sandbox.
    case wasm

    /// A provider implemented by a remote service, such as an AI coding service.
    case remoteService
}

enum PluginPermission: String, Codable, CaseIterable, Hashable, Sendable {
    /// Read files inside the currently opened iSwift Code workspace.
    case workspaceRead

    /// Create, replace, rename, or delete files inside the current workspace.
    case workspaceWrite

    /// Access network services through host-provided networking APIs.
    case network

    /// Import or export files through host-controlled document access.
    case userFiles

    /// Read or write the clipboard through a host-controlled API.
    case clipboard

    /// Use credentials stored through a host-controlled credential provider.
    case credentials

    /// Read or create build products managed by iSwift Code.
    case buildArtifacts

    /// Ask the host to open an external URL.
    case openExternalURL
}

enum PluginManifestValidationError: Error, Equatable, Sendable {
    case invalidIdentifier
    case invalidDisplayName
    case invalidVersion
    case invalidAPIVersion
    case emptyCapabilities
    case remoteServiceRequiresNetworkPermission
}

extension PluginManifestValidationError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidIdentifier:
            return "Plugin identifier must use a reverse-domain style identifier."
        case .invalidDisplayName:
            return "Plugin display name cannot be empty."
        case .invalidVersion:
            return "Plugin version cannot be empty."
        case .invalidAPIVersion:
            return "Plugin API version must be greater than zero."
        case .emptyCapabilities:
            return "Plugin must declare at least one capability."
        case .remoteServiceRequiresNetworkPermission:
            return "Remote service plugins must request the network permission."
        }
    }
}

struct PluginManifest: Codable, Hashable, Sendable {
    static let currentAPIVersion = 1

    let identifier: String
    let displayName: String
    let version: String
    let apiVersion: Int
    let capabilities: Set<PluginCapability>
    let requiredPermissions: Set<PluginPermission>
    let executionMode: PluginExecutionMode

    init(
        identifier: String,
        displayName: String,
        version: String,
        apiVersion: Int = PluginManifest.currentAPIVersion,
        capabilities: Set<PluginCapability>,
        requiredPermissions: Set<PluginPermission> = [],
        executionMode: PluginExecutionMode
    ) {
        self.identifier = identifier
        self.displayName = displayName
        self.version = version
        self.apiVersion = apiVersion
        self.capabilities = capabilities
        self.requiredPermissions = requiredPermissions
        self.executionMode = executionMode
    }

    func validate() throws {
        guard Self.isValidIdentifier(identifier) else {
            throw PluginManifestValidationError.invalidIdentifier
        }
        guard !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PluginManifestValidationError.invalidDisplayName
        }
        guard !version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PluginManifestValidationError.invalidVersion
        }
        guard apiVersion > 0 else {
            throw PluginManifestValidationError.invalidAPIVersion
        }
        guard !capabilities.isEmpty else {
            throw PluginManifestValidationError.emptyCapabilities
        }
        if executionMode == .remoteService, !requiredPermissions.contains(.network) {
            throw PluginManifestValidationError.remoteServiceRequiresNetworkPermission
        }
    }

    private static func isValidIdentifier(_ identifier: String) -> Bool {
        let components = identifier.split(separator: ".", omittingEmptySubsequences: false)
        guard components.count >= 2 else { return false }

        for component in components {
            guard !component.isEmpty else { return false }
            for character in component {
                guard character.isLetter || character.isNumber || character == "-" || character == "_" else {
                    return false
                }
            }
        }
        return true
    }
}
