import Foundation

enum PluginCapability: String, Codable, CaseIterable, Hashable, Sendable {
    case compiler
    case aiAssistant
    case preview
    case editor
    case build
    case projectTemplate
    case runtime
    case formatter
    case languageServer
}

enum PluginExecutionMode: String, Codable, CaseIterable, Hashable, Sendable {
    case builtIn
    case wasm
    case remoteService
}

enum PluginPermission: String, Codable, CaseIterable, Hashable, Sendable {
    case workspaceRead
    case workspaceWrite
    case network
    case userFiles
    case clipboard
    case credentials
    case buildArtifacts
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
