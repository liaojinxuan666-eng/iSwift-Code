import XCTest
@testable import iSwiftCode

final class PluginFoundationTests: XCTestCase {
    private final class TestPlugin: ISwiftPlugin {
        let manifest: PluginManifest
        private(set) var activationCount = 0
        private(set) var deactivationCount = 0
        private(set) var lastContext: PluginHostContext?

        init(manifest: PluginManifest) {
            self.manifest = manifest
        }

        func activate(context: PluginHostContext) throws {
            activationCount += 1
            lastContext = context
        }

        func deactivate() {
            deactivationCount += 1
        }
    }

    private func makePlugin(
        identifier: String = "com.iswift.tests.sample",
        capabilities: Set<PluginCapability> = [.editor],
        permissions: Set<PluginPermission> = [],
        executionMode: PluginExecutionMode = .builtIn,
        apiVersion: Int = PluginManifest.currentAPIVersion
    ) -> TestPlugin {
        TestPlugin(
            manifest: PluginManifest(
                identifier: identifier,
                displayName: "Sample Plugin",
                version: "1.0.0",
                apiVersion: apiVersion,
                capabilities: capabilities,
                requiredPermissions: permissions,
                executionMode: executionMode
            )
        )
    }

    func testManifestRoundTripsThroughJSON() throws {
        let manifest = PluginManifest(
            identifier: "com.iswift.tests.compiler",
            displayName: "Compiler Plugin",
            version: "1.2.3",
            capabilities: [.compiler, .formatter],
            requiredPermissions: [.workspaceRead, .buildArtifacts],
            executionMode: .wasm
        )

        let encoded = try JSONEncoder().encode(manifest)
        let decoded = try JSONDecoder().decode(PluginManifest.self, from: encoded)

        XCTAssertEqual(decoded, manifest)
    }

    func testDuplicateIdentifierIsRejected() throws {
        let registry = PluginRegistry()
        try registry.register(makePlugin())

        XCTAssertThrowsError(try registry.register(makePlugin())) { error in
            XCTAssertEqual(
                error as? PluginRegistryError,
                .duplicateIdentifier("com.iswift.tests.sample")
            )
        }
    }

    func testIncompatibleAPIVersionIsRejected() {
        let registry = PluginRegistry()
        let plugin = makePlugin(apiVersion: PluginManifest.currentAPIVersion + 1)

        XCTAssertThrowsError(try registry.register(plugin)) { error in
            XCTAssertEqual(
                error as? PluginRegistryError,
                .incompatibleAPIVersion(
                    expected: PluginManifest.currentAPIVersion,
                    found: PluginManifest.currentAPIVersion + 1
                )
            )
        }
    }

    func testCapabilityQuery() throws {
        let registry = PluginRegistry()

        try registry.register(
            makePlugin(
                identifier: "com.iswift.tests.compiler",
                capabilities: [.compiler]
            )
        )
        try registry.register(
            makePlugin(
                identifier: "com.iswift.tests.ai",
                capabilities: [.aiAssistant],
                permissions: [.network],
                executionMode: .remoteService
            )
        )

        XCTAssertEqual(
            registry.manifests(capability: .compiler).map(\.identifier),
            ["com.iswift.tests.compiler"]
        )
        XCTAssertEqual(
            registry.manifests(capability: .aiAssistant).map(\.identifier),
            ["com.iswift.tests.ai"]
        )
    }

    func testActivationRequiresEveryDeclaredPermission() throws {
        let registry = PluginRegistry()
        let plugin = makePlugin(
            permissions: [.workspaceRead, .workspaceWrite]
        )
        try registry.register(plugin)

        XCTAssertThrowsError(
            try registry.activate(
                identifier: plugin.manifest.identifier,
                grantedPermissions: [.workspaceRead]
            )
        ) { error in
            XCTAssertEqual(
                error as? PluginRegistryError,
                .missingPermissions(
                    plugin: plugin.manifest.identifier,
                    permissions: [.workspaceWrite]
                )
            )
        }

        XCTAssertEqual(plugin.activationCount, 0)
    }

    func testActivationAndDeactivationLifecycle() throws {
        let registry = PluginRegistry()
        let plugin = makePlugin(permissions: [.workspaceRead])
        try registry.register(plugin)

        try registry.activate(
            identifier: plugin.manifest.identifier,
            grantedPermissions: [.workspaceRead]
        )

        XCTAssertEqual(try registry.state(identifier: plugin.manifest.identifier), .active)
        XCTAssertEqual(plugin.activationCount, 1)
        XCTAssertTrue(plugin.lastContext?.hasPermission(.workspaceRead) == true)

        try registry.deactivate(identifier: plugin.manifest.identifier)

        XCTAssertEqual(try registry.state(identifier: plugin.manifest.identifier), .enabled)
        XCTAssertEqual(plugin.deactivationCount, 1)
    }

    func testDisablingAnActivePluginDeactivatesIt() throws {
        let registry = PluginRegistry()
        let plugin = makePlugin()
        try registry.register(plugin)
        try registry.activate(identifier: plugin.manifest.identifier, grantedPermissions: [])

        try registry.setEnabled(false, identifier: plugin.manifest.identifier)

        XCTAssertEqual(try registry.state(identifier: plugin.manifest.identifier), .disabled)
        XCTAssertEqual(plugin.deactivationCount, 1)
    }

    func testRemoteServiceMustRequestNetworkPermission() {
        let registry = PluginRegistry()
        let plugin = makePlugin(
            capabilities: [.aiAssistant],
            executionMode: .remoteService
        )

        XCTAssertThrowsError(try registry.register(plugin)) { error in
            XCTAssertEqual(
                error as? PluginRegistryError,
                .invalidManifest(.remoteServiceRequiresNetworkPermission)
            )
        }
    }

    func testPluginHostContextRejectsUngrantPermission() {
        let context = PluginHostContext(
            pluginIdentifier: "com.iswift.tests.sample",
            grantedPermissions: [.workspaceRead]
        )

        XCTAssertNoThrow(try context.requirePermission(.workspaceRead))
        XCTAssertThrowsError(try context.requirePermission(.network)) { error in
            XCTAssertEqual(
                error as? PluginHostContextError,
                .permissionDenied(.network)
            )
        }
    }
}
