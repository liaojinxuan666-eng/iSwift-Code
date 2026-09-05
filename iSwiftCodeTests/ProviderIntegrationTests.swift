import XCTest
@testable import iSwiftCode

final class ProviderIntegrationTests: XCTestCase {
    private final class MockAIProvider: AIProvider {
        let manifest = PluginManifest(
            identifier: "com.iswift.tests.ai-provider",
            displayName: "Test AI Provider",
            version: "1.0.0",
            capabilities: [.aiAssistant],
            requiredPermissions: [.network],
            executionMode: .remoteService
        )

        let providerName = "Test AI"
        let supportedTasks: Set<AITask> = [.chat]

        func perform(_ request: AIProviderRequest) async throws -> AIProviderResponse {
            guard supportedTasks.contains(request.task) else {
                throw AIProviderError.unsupportedTask(request.task)
            }
            return AIProviderResponse(message: "ok")
        }
    }

    func testSandboxProviderIsBuiltInCompilerPlugin() {
        let provider = SandboxSwiftCompilerProvider()

        XCTAssertEqual(provider.manifest.executionMode, .builtIn)
        XCTAssertTrue(provider.manifest.capabilities.contains(.compiler))
        XCTAssertEqual(provider.supportedLanguages, [.swift])
        XCTAssertTrue(provider.supportedOperations.contains(.run))
    }

    func testSandboxProviderRunsSwiftThroughProviderBoundary() throws {
        let provider = SandboxSwiftCompilerProvider()
        let result = try provider.perform(
            .singleFile(
                operation: .run,
                language: .swift,
                path: "main.swift",
                source: "print(40 + 2)"
            )
        )

        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(result.output, "42")
        XCTAssertNotNil(result.metrics.instructionCount)
    }

    func testSandboxProviderRejectsUnsupportedLanguage() {
        let provider = SandboxSwiftCompilerProvider()
        let request = CompilerRequest.singleFile(
            operation: .compile,
            language: .c,
            path: "main.c",
            source: "int main(void) { return 0; }"
        )

        XCTAssertThrowsError(try provider.perform(request)) { error in
            XCTAssertEqual(error as? CompilerProviderError, .unsupportedLanguage(.c))
        }
    }

    func testSandboxProviderRejectsMultipleFilesForNow() {
        let provider = SandboxSwiftCompilerProvider()
        let request = CompilerRequest(
            operation: .compile,
            files: [
                CompilerSourceFile(path: "A.swift", contents: "let a = 1", language: .swift),
                CompilerSourceFile(path: "B.swift", contents: "let b = 2", language: .swift)
            ]
        )

        XCTAssertThrowsError(try provider.perform(request)) { error in
            guard let providerError = error as? CompilerProviderError,
                  case .invalidRequest = providerError else {
                return XCTFail("Expected invalidRequest, got \(error)")
            }
        }
    }

    func testRegistryDiscoversCompilerProvider() throws {
        let registry = PluginRegistry()
        let provider = SandboxSwiftCompilerProvider()

        try registry.register(provider)

        XCTAssertEqual(
            registry.compilerProviders().map { $0.manifest.identifier },
            [provider.manifest.identifier]
        )
        XCTAssertEqual(
            try registry.compilerProvider(identifier: provider.manifest.identifier).providerName,
            provider.providerName
        )
    }

    func testDisabledProviderIsHiddenFromDefaultDiscovery() throws {
        let registry = PluginRegistry()
        let provider = SandboxSwiftCompilerProvider()
        try registry.register(provider, enabled: false)

        XCTAssertTrue(registry.compilerProviders().isEmpty)
        XCTAssertEqual(registry.compilerProviders(enabledOnly: false).count, 1)
    }

    func testRegistryDiscoversAIProviderSeparately() throws {
        let registry = PluginRegistry()
        let provider = MockAIProvider()
        try registry.register(provider)

        XCTAssertEqual(registry.aiProviders().map { $0.manifest.identifier }, [provider.manifest.identifier])
        XCTAssertTrue(registry.compilerProviders().isEmpty)
    }

    func testWrongProviderKindReturnsCapabilityMismatch() throws {
        let registry = PluginRegistry()
        let provider = SandboxSwiftCompilerProvider()
        try registry.register(provider)

        XCTAssertThrowsError(try registry.aiProvider(identifier: provider.manifest.identifier)) { error in
            XCTAssertEqual(
                error as? PluginRegistryError,
                .capabilityMismatch(plugin: provider.manifest.identifier, required: .aiAssistant)
            )
        }
    }

    func testWasmPackageCarriesManifestAndModule() {
        let manifest = PluginManifest(
            identifier: "com.iswift.tests.wasm",
            displayName: "Wasm Test",
            version: "1.0.0",
            capabilities: [.formatter],
            executionMode: .wasm
        )
        let package = WasmPluginPackage(manifest: manifest, moduleData: Data([0x00, 0x61, 0x73, 0x6D]))

        XCTAssertEqual(package.manifest, manifest)
        XCTAssertFalse(package.moduleData.isEmpty)
        XCTAssertEqual(WasmPluginResourceLimits.default.maximumMemoryBytes, 64 * 1024 * 1024)
    }
}
