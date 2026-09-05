import Foundation

enum PluginRegistryError: Error, Equatable, Sendable {
    case invalidManifest(PluginManifestValidationError)
    case duplicateIdentifier(String)
    case incompatibleAPIVersion(expected: Int, found: Int)
    case pluginNotFound(String)
    case pluginDisabled(String)
    case capabilityMismatch(plugin: String, required: PluginCapability)
    case missingPermissions(plugin: String, permissions: Set<PluginPermission>)
}

extension PluginRegistryError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidManifest(let error): return error.localizedDescription
        case .duplicateIdentifier(let identifier): return "A plugin with identifier '\(identifier)' is already registered."
        case .incompatibleAPIVersion(let expected, let found): return "Plugin API version \(found) is incompatible with host API version \(expected)."
        case .pluginNotFound(let identifier): return "Plugin '\(identifier)' is not registered."
        case .pluginDisabled(let identifier): return "Plugin '\(identifier)' is disabled."
        case .capabilityMismatch(let plugin, let required): return "Plugin '\(plugin)' does not provide capability '\(required.rawValue)'."
        case .missingPermissions(let plugin, let permissions):
            let names = permissions.map(\.rawValue).sorted().joined(separator: ", ")
            return "Plugin '\(plugin)' is missing required permissions: \(names)."
        }
    }
}

final class PluginRegistry {
    static let hostAPIVersion = PluginManifest.currentAPIVersion

    private var plugins: [String: ISwiftPlugin] = [:]
    private var enabledIdentifiers: Set<String> = []
    private var activeIdentifiers: Set<String> = []

    var manifests: [PluginManifest] {
        plugins.values.map(\.manifest).sorted { $0.identifier < $1.identifier }
    }

    func register(_ plugin: ISwiftPlugin, enabled: Bool = true) throws {
        let manifest = plugin.manifest
        do { try manifest.validate() }
        catch let error as PluginManifestValidationError { throw PluginRegistryError.invalidManifest(error) }

        guard manifest.apiVersion == Self.hostAPIVersion else {
            throw PluginRegistryError.incompatibleAPIVersion(expected: Self.hostAPIVersion, found: manifest.apiVersion)
        }
        guard plugins[manifest.identifier] == nil else {
            throw PluginRegistryError.duplicateIdentifier(manifest.identifier)
        }
        plugins[manifest.identifier] = plugin
        if enabled { enabledIdentifiers.insert(manifest.identifier) }
    }

    func unregister(identifier: String) throws {
        guard let plugin = plugins[identifier] else { throw PluginRegistryError.pluginNotFound(identifier) }
        if activeIdentifiers.contains(identifier) {
            plugin.deactivate()
            activeIdentifiers.remove(identifier)
        }
        enabledIdentifiers.remove(identifier)
        plugins.removeValue(forKey: identifier)
    }

    func plugin(identifier: String) -> ISwiftPlugin? { plugins[identifier] }
    func manifest(identifier: String) -> PluginManifest? { plugins[identifier]?.manifest }
    func manifests(capability: PluginCapability) -> [PluginManifest] { manifests.filter { $0.capabilities.contains(capability) } }

    func compilerProviders(enabledOnly: Bool = true) -> [any CompilerProvider] {
        plugins.values.compactMap { plugin in
            guard let provider = plugin as? any CompilerProvider else { return nil }
            if enabledOnly, !enabledIdentifiers.contains(provider.manifest.identifier) { return nil }
            return provider
        }.sorted { $0.manifest.identifier < $1.manifest.identifier }
    }

    func aiProviders(enabledOnly: Bool = true) -> [any AIProvider] {
        plugins.values.compactMap { plugin in
            guard let provider = plugin as? any AIProvider else { return nil }
            if enabledOnly, !enabledIdentifiers.contains(provider.manifest.identifier) { return nil }
            return provider
        }.sorted { $0.manifest.identifier < $1.manifest.identifier }
    }

    func previewProviders(enabledOnly: Bool = true) -> [any PreviewProvider] {
        plugins.values.compactMap { plugin in
            guard let provider = plugin as? any PreviewProvider else { return nil }
            if enabledOnly, !enabledIdentifiers.contains(provider.manifest.identifier) { return nil }
            return provider
        }.sorted { $0.manifest.identifier < $1.manifest.identifier }
    }

    func compilerProvider(identifier: String) throws -> any CompilerProvider {
        guard let plugin = plugins[identifier] else { throw PluginRegistryError.pluginNotFound(identifier) }
        guard enabledIdentifiers.contains(identifier) else { throw PluginRegistryError.pluginDisabled(identifier) }
        guard let provider = plugin as? any CompilerProvider else {
            throw PluginRegistryError.capabilityMismatch(plugin: identifier, required: .compiler)
        }
        return provider
    }

    func aiProvider(identifier: String) throws -> any AIProvider {
        guard let plugin = plugins[identifier] else { throw PluginRegistryError.pluginNotFound(identifier) }
        guard enabledIdentifiers.contains(identifier) else { throw PluginRegistryError.pluginDisabled(identifier) }
        guard let provider = plugin as? any AIProvider else {
            throw PluginRegistryError.capabilityMismatch(plugin: identifier, required: .aiAssistant)
        }
        return provider
    }

    func previewProvider(identifier: String) throws -> any PreviewProvider {
        guard let plugin = plugins[identifier] else { throw PluginRegistryError.pluginNotFound(identifier) }
        guard enabledIdentifiers.contains(identifier) else { throw PluginRegistryError.pluginDisabled(identifier) }
        guard let provider = plugin as? any PreviewProvider else {
            throw PluginRegistryError.capabilityMismatch(plugin: identifier, required: .preview)
        }
        return provider
    }

    func state(identifier: String) throws -> PluginLifecycleState {
        guard plugins[identifier] != nil else { throw PluginRegistryError.pluginNotFound(identifier) }
        if activeIdentifiers.contains(identifier) { return .active }
        return enabledIdentifiers.contains(identifier) ? .enabled : .disabled
    }

    func setEnabled(_ enabled: Bool, identifier: String) throws {
        guard let plugin = plugins[identifier] else { throw PluginRegistryError.pluginNotFound(identifier) }
        if enabled { enabledIdentifiers.insert(identifier); return }
        if activeIdentifiers.contains(identifier) {
            plugin.deactivate()
            activeIdentifiers.remove(identifier)
        }
        enabledIdentifiers.remove(identifier)
    }

    func activate(
        identifier: String,
        grantedPermissions: Set<PluginPermission>,
        serviceBackends: PluginHostServiceBackends = .empty
    ) throws {
        guard let plugin = plugins[identifier] else { throw PluginRegistryError.pluginNotFound(identifier) }
        guard enabledIdentifiers.contains(identifier) else { throw PluginRegistryError.pluginDisabled(identifier) }
        let required = plugin.manifest.requiredPermissions
        let missing = required.subtracting(grantedPermissions)
        guard missing.isEmpty else {
            throw PluginRegistryError.missingPermissions(plugin: identifier, permissions: missing)
        }
        if activeIdentifiers.contains(identifier) { return }
        let effectivePermissions = grantedPermissions.intersection(required)
        let context = PluginHostContext(
            pluginIdentifier: identifier,
            grantedPermissions: effectivePermissions,
            serviceBackends: serviceBackends
        )
        try plugin.activate(context: context)
        activeIdentifiers.insert(identifier)
    }

    func deactivate(identifier: String) throws {
        guard let plugin = plugins[identifier] else { throw PluginRegistryError.pluginNotFound(identifier) }
        guard activeIdentifiers.contains(identifier) else { return }
        plugin.deactivate()
        activeIdentifiers.remove(identifier)
    }
}
