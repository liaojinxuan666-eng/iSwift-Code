import XCTest
@testable import iSwiftCode

final class PluginHostServicesTests: XCTestCase {
    private final class MemoryWorkspaceBackend: PluginWorkspaceHostBackend, @unchecked Sendable {
        var files: [String: Data]

        init(files: [String: Data] = [:]) {
            self.files = files
        }

        func listFiles() throws -> [String] {
            files.keys.sorted()
        }

        func readFile(at path: String) throws -> Data {
            files[path] ?? Data()
        }

        func writeFile(_ data: Data, at path: String) throws {
            files[path] = data
        }

        func deleteFile(at path: String) throws {
            files.removeValue(forKey: path)
        }

        func moveFile(from sourcePath: String, to destinationPath: String) throws {
            let data = files.removeValue(forKey: sourcePath) ?? Data()
            files[destinationPath] = data
        }
    }

    private final class FixedNetworkBackend: PluginNetworkHostBackend, @unchecked Sendable {
        func send(_ request: PluginNetworkRequest) async throws -> PluginNetworkResponse {
            PluginNetworkResponse(
                statusCode: 200,
                headers: ["X-Plugin-Test": request.method],
                body: Data("ok".utf8)
            )
        }
    }

    private final class MemoryCredentialBackend: PluginCredentialHostBackend, @unchecked Sendable {
        var values: [String: Data] = [:]

        func data(forKey key: String) throws -> Data? {
            values[key]
        }

        func setData(_ data: Data, forKey key: String) throws {
            values[key] = data
        }

        func removeData(forKey key: String) throws {
            values.removeValue(forKey: key)
        }
    }

    private final class CapturingPlugin: ISwiftPlugin {
        let manifest: PluginManifest
        private(set) var context: PluginHostContext?

        init(requiredPermissions: Set<PluginPermission>) {
            manifest = PluginManifest(
                identifier: "com.iswift.tests.host-services",
                displayName: "Host Services Test",
                version: "1.0.0",
                capabilities: [.editor],
                requiredPermissions: requiredPermissions,
                executionMode: .builtIn
            )
        }

        func activate(context: PluginHostContext) throws {
            self.context = context
        }
    }

    func testWorkspaceReadRequiresPermissionAtServiceBoundary() {
        let backend = MemoryWorkspaceBackend(
            files: ["main.swift": Data("print(42)".utf8)]
        )
        let services = PluginHostServices(
            pluginIdentifier: "com.iswift.tests.denied",
            grantedPermissions: [],
            backends: PluginHostServiceBackends(workspace: backend)
        )

        XCTAssertThrowsError(try services.readWorkspaceFile(at: "main.swift")) { error in
            XCTAssertEqual(
                error as? PluginHostContextError,
                .permissionDenied(.workspaceRead)
            )
        }
    }

    func testWorkspaceBackendIsUsableThroughPermissionCheckedFacade() throws {
        let backend = MemoryWorkspaceBackend(
            files: ["main.swift": Data("old".utf8)]
        )
        let services = PluginHostServices(
            pluginIdentifier: "com.iswift.tests.workspace",
            grantedPermissions: [.workspaceRead, .workspaceWrite],
            backends: PluginHostServiceBackends(workspace: backend)
        )

        XCTAssertEqual(
            String(decoding: try services.readWorkspaceFile(at: "main.swift"), as: UTF8.self),
            "old"
        )

        try services.writeWorkspaceFile(Data("new".utf8), at: "main.swift")
        XCTAssertEqual(
            String(decoding: try services.readWorkspaceFile(at: "main.swift"), as: UTF8.self),
            "new"
        )

        try services.moveWorkspaceFile(from: "main.swift", to: "Sources/main.swift")
        XCTAssertEqual(try services.listWorkspaceFiles(), ["Sources/main.swift"])

        try services.deleteWorkspaceFile(at: "Sources/main.swift")
        XCTAssertEqual(try services.listWorkspaceFiles(), [])
    }

    func testWorkspaceWriteDoesNotImplicitlyGrantRead() throws {
        let backend = MemoryWorkspaceBackend()
        let services = PluginHostServices(
            pluginIdentifier: "com.iswift.tests.write-only",
            grantedPermissions: [.workspaceWrite],
            backends: PluginHostServiceBackends(workspace: backend)
        )

        XCTAssertNoThrow(
            try services.writeWorkspaceFile(Data("value".utf8), at: "value.txt")
        )
        XCTAssertThrowsError(try services.readWorkspaceFile(at: "value.txt")) { error in
            XCTAssertEqual(
                error as? PluginHostContextError,
                .permissionDenied(.workspaceRead)
            )
        }
    }

    func testCredentialBackendRequiresCredentialPermission() throws {
        let backend = MemoryCredentialBackend()
        let services = PluginHostServices(
            pluginIdentifier: "com.iswift.tests.credentials",
            grantedPermissions: [.credentials],
            backends: PluginHostServiceBackends(credentials: backend)
        )

        try services.writeCredential(Data("secret".utf8), forKey: "token")
        XCTAssertEqual(
            String(decoding: try XCTUnwrap(services.readCredential(forKey: "token")), as: UTF8.self),
            "secret"
        )
        try services.removeCredential(forKey: "token")
        XCTAssertNil(try services.readCredential(forKey: "token"))
    }

    func testNetworkServiceUsesHostBackend() async throws {
        let services = PluginHostServices(
            pluginIdentifier: "com.iswift.tests.network",
            grantedPermissions: [.network],
            backends: PluginHostServiceBackends(network: FixedNetworkBackend())
        )
        let request = PluginNetworkRequest(
            method: "POST",
            url: try XCTUnwrap(URL(string: "https://example.invalid/test"))
        )

        let response = try await services.sendNetworkRequest(request)

        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(response.headers["X-Plugin-Test"], "POST")
        XCTAssertEqual(String(decoding: response.body, as: UTF8.self), "ok")
    }

    func testPermissionMayPassWhileBackendIsUnavailable() async throws {
        let services = PluginHostServices(
            pluginIdentifier: "com.iswift.tests.no-network-backend",
            grantedPermissions: [.network]
        )
        let request = PluginNetworkRequest(
            url: try XCTUnwrap(URL(string: "https://example.invalid"))
        )

        do {
            _ = try await services.sendNetworkRequest(request)
            XCTFail("Expected the missing network backend to be rejected.")
        } catch {
            XCTAssertEqual(
                error as? PluginHostServiceError,
                .serviceUnavailable("network")
            )
        }
    }

    func testRegistryNeverPassesUndeclaredExtraPermissionsToPlugin() throws {
        let registry = PluginRegistry()
        let plugin = CapturingPlugin(requiredPermissions: [.workspaceRead])
        try registry.register(plugin)

        try registry.activate(
            identifier: plugin.manifest.identifier,
            grantedPermissions: [.workspaceRead, .network],
            serviceBackends: PluginHostServiceBackends(network: FixedNetworkBackend())
        )

        let context = try XCTUnwrap(plugin.context)
        XCTAssertTrue(context.hasPermission(.workspaceRead))
        XCTAssertFalse(context.hasPermission(.network))
        XCTAssertEqual(context.grantedPermissions, [.workspaceRead])
    }
}
