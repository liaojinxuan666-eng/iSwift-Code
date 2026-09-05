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

/// The only host information a plugin receives during activation in the first
/// plugin API version. Host services will be added behind permission-checked
/// interfaces instead of exposing app internals directly.
struct PluginHostContext: Sendable {
    let pluginIdentifier: String
    let grantedPermissions: Set<PluginPermission>

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
