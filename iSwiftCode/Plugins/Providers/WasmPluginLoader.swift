import Foundation

struct WasmPluginPackage: Sendable {
    let manifest: PluginManifest
    let moduleData: Data

    init(manifest: PluginManifest, moduleData: Data) {
        self.manifest = manifest
        self.moduleData = moduleData
    }
}

struct WasmPluginResourceLimits: Equatable, Sendable {
    let maximumMemoryBytes: Int
    let maximumInstructionCount: Int

    static let `default` = WasmPluginResourceLimits(
        maximumMemoryBytes: 64 * 1024 * 1024,
        maximumInstructionCount: 5_000_000
    )
}

enum WasmPluginLoaderError: Error, Equatable, Sendable {
    case invalidExecutionMode
    case invalidManifest(PluginManifestValidationError)
    case emptyModule
    case unsupportedAPIVersion(expected: Int, found: Int)
    case runtimeUnavailable
}

extension WasmPluginLoaderError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidExecutionMode:
            return "Wasm loader only accepts plugins whose execution mode is 'wasm'."
        case .invalidManifest(let error):
            return error.localizedDescription
        case .emptyModule:
            return "Wasm plugin module is empty."
        case .unsupportedAPIVersion(let expected, let found):
            return "Wasm plugin API version \(found) is incompatible with host API version \(expected)."
        case .runtimeUnavailable:
            return "WebAssembly plugin runtime is not available yet."
        }
    }
}

protocol WasmPluginLoader {
    func instantiate(
        package: WasmPluginPackage,
        context: PluginHostContext,
        limits: WasmPluginResourceLimits
    ) throws -> ISwiftPlugin
}
