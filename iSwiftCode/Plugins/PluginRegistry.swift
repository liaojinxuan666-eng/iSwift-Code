import Foundation

enum PluginRegistryError: Error, Equatable, Sendable {
    case invalidManifest(PluginManifestValidationError)
    case duplicateIdentifier(String)
    case incompatibleAPIVersion(expected: Int, found: Int)
    case pluginNotFound(String)
    case pluginDisabled(String)
    case missingPermissions(plugin: String, permissions: Set<PluginPermission>)
}

extension PluginRegistryError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidManifest(let error):
            return error.localizedDescription
        case .duplicateIdentifier(let identifier):
            return "A plugin with identifier '\(identifier)' is already registered."
        case .incompatibleAPIVersion(let expected, let found):
            return "Plugin API version \(found) is incompatible with host API version \(expected)."
        case .pluginNotFound(let identifier):
            return "Plugin '\(identifier)' is not registered."
        case .pluginDisabled(let identifier):
            return "Plugin '\(identifier)' is disabled."
        case .missingPermissions(let plugin, let permissions):
            let names = permissions.map(\.rawValue).sorted().joined(separator: ", ")
            return "Plugin '\(plugin)' is missing required permissions: \(names)."
        }
    }
}

/// In-memory registry for the first plugin API.
///
/// The registry owns lifecycle state and enforces manifest compatibility and
/// permission grants. Persistent installation/enabled state will be layered on
/// top later without changing the plugin protocol.
final class PluginRegistry {
    static let hostAPIVersion = PluginManifest.currentAPIVersion

    private var plugins: [String: ISwiftPlugin] = [:]
    private var enabledIdentifiers: Set<String> = []
    private var activeIdentifiers: Set<String> = []

    var manifests: [PluginManifest] {
        plugins.values
            .map(\.manifest)
            .sorted { $0.identifier < $1.identifier }
    }

    func register(_ plugin: ISwiftPlugin, enabled: Bool = true) throws {
        let manifest = plugin.manifest

        do {
            try manifest.validate()
        } catch let error as PluginManifestValidationError {
            throw PluginRegistryError.invalidManifest(error)
        }

        guard manifest.apiVersion == Self.hostAPIVersion else {
            throw PluginRegistryError.incompatibleAPIVersion(
                expected: Self.hostAPIVersion,
                found: manifest.apiVersion
            )
        }

        guard plugins[manifest.identifier] == nil else {
            throw PluginRegistryError.duplicateIdentifier(manifest.identifier)
        }

        plugins[manifest.identifier] = plugin
        if enabled {
            enabledIdentifiers.insert(manifest.identifier)
        }
    }

    func unregister(identifier: String) throws {
        guard let plugin = plugins[identifier] else {
            throw PluginRegistryError.pluginNotFound(identifier)
        }

        if activeIdentifiers.contains(identifier) {
            plugin.deactivate()
            activeIdentifiers.remove(identifier)
        }

        enabledIdentifiers.remove(identifier)
        plugins.removeValue(forKey: identifier)
    }

    func manifest(identifier: String) -> PluginManifest? {
        plugins[identifier]?.manifest
    }

    func manifests(capability: PluginCapability) -> [PluginManifest] {
        manifests.filter { $0.capabilities.contains(capability) }
    }

    func state(identifier: String) throws -> PluginLifecycleState {
        guard plugins[identifier] != nil else {
            throw PluginRegistryError.pluginNotFound(identifier)
        }
        if activeIdentifiers.contains(identifier) {
            return .active
        }
        return enabledIdentifiers.contains(identifier) ? .enabled : .disabled
    }

    func setEnabled(_ enabled: Bool, identifier: String) throws {
        guard let plugin = plugins[identifier] else {
            throw PluginRegistryError.pluginNotFound(identifier)
        }

        if enabled {
            enabledIdentifiers.insert(identifier)
            return
        }

        if activeIdentifiers.contains(identifier) {
            plugin.deactivate()
            activeIdentifiers.remove(identifier)
        }
        enabledIdentifiers.remove(identifier)
    }

    func activate(
        identifier: String,
        grantedPermissions: Set<PluginPermission>
    ) throws {
        guard let plugin = plugins[identifier] else {
            throw PluginRegistryError.pluginNotFound(identifier)
        }
        guard enabledIdentifiers.contains(identifier) else {
            throw PluginRegistryError.pluginDisabled(identifier)
        }

        let required = plugin.manifest.requiredPermissions
        let missing = required.subtracting(grantedPermissions)
        guard missing.isEmpty else {
            throw PluginRegistryError.missingPermissions(
                plugin: identifier,
                permissions: missing
            )
        }

        if activeIdentifiers.contains(identifier) {
            return
        }

        let context = PluginHostContext(
            pluginIdentifier: identifier,
            grantedPermissions: grantedPermissions
        )
        try plugin.activate(context: context)
        activeIdentifiers.insert(identifier)
    }

    func deactivate(identifier: String) throws {
        guard let plugin = plugins[identifier] else {
            throw PluginRegistryError.pluginNotFound(identifier)
        }
        guard activeIdentifiers.contains(identifier) else {
            return
        }

        plugin.deactivate()
        activeIdentifiers.remove(identifier)
    }
}
