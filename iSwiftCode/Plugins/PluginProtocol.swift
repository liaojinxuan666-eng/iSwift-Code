import Foundation

enum PluginLifecycleState: String, Equatable, Sendable {
    case disabled
    case enabled
    case active
}

enum PluginHostContextError: Error, Equatable, Sendable {
    case permissionDenied(PluginPermission)
}

extension PluginHostContextError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .permissionDenied(let permission):
            return "Plugin permission denied: \(permission.rawValue)."
        }
    }
}

/// Host context issued by iSwift Code when a plugin is activated.
///
/// Plugins receive only their effective granted permissions and a
/// permission-checked host-service facade. They never receive the raw backend
/// implementations used by the app.
struct PluginHostContext: Sendable {
    let pluginIdentifier: String
    let grantedPermissions: Set<PluginPermission>
    let services: PluginHostServices

    init(
        pluginIdentifier: String,
        grantedPermissions: Set<PluginPermission>,
        serviceBackends: PluginHostServiceBackends = .empty
    ) {
        self.pluginIdentifier = pluginIdentifier
        self.grantedPermissions = grantedPermissions
        services = PluginHostServices(
            pluginIdentifier: pluginIdentifier,
            grantedPermissions: grantedPermissions,
            backends: serviceBackends
        )
    }

    func hasPermission(_ permission: PluginPermission) -> Bool {
        grantedPermissions.contains(permission)
    }

    func requirePermission(_ permission: PluginPermission) throws {
        guard hasPermission(permission) else {
            throw PluginHostContextError.permissionDenied(permission)
        }
    }
}

/// Base protocol for every iSwift Code plugin.
///
/// A plugin does not receive unrestricted access to iSwift Code internals.
/// Capabilities are declared in PluginManifest and actual host services are
/// granted through PluginHostContext.
protocol ISwiftPlugin: AnyObject {
    var manifest: PluginManifest { get }

    func activate(context: PluginHostContext) throws
    func deactivate()
}

extension ISwiftPlugin {
    func activate(context: PluginHostContext) throws {}
    func deactivate() {}
}
