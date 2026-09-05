import Foundation
import XCTest
@testable import iSwiftCode

final class PreviewFoundationTests: XCTestCase {
    func testPreviewProviderManifestUsesPreviewCapability() {
        let provider = SwiftUIPreviewProvider()
        XCTAssertTrue(provider.manifest.capabilities.contains(.preview))
        XCTAssertEqual(provider.manifest.executionMode, .builtIn)
    }

    func testRegistryDiscoversPreviewProvider() throws {
        let registry = PluginRegistry()
        let provider = SwiftUIPreviewProvider()
        try registry.register(provider)

        XCTAssertEqual(registry.previewProviders().map { $0.manifest.identifier }, [provider.manifest.identifier])
        XCTAssertEqual(try registry.previewProvider(identifier: provider.manifest.identifier).providerName, "SwiftUI Preview")
    }

    func testSwiftUIProviderBuildsStructuralPreviewTree() throws {
        let source = """
        import SwiftUI
        struct ContentView: View {
            var body: some View {
                VStack {
                    Image(systemName: "swift")
                    Text("Hello")
                    HStack {
                        Button("Run") { }
                        Spacer()
                        Text("Ready")
                    }
                }
            }
        }
        """

        let result = try SwiftUIPreviewProvider().makePreview(
            PreviewRequest(
                files: [PreviewSourceFile(path: "ContentView.swift", contents: source)],
                entryFilePath: "ContentView.swift"
            )
        )

        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(
            result.document?.root,
            .vStack(children: [
                .image(systemName: "swift"),
                .text("Hello"),
                .hStack(children: [
                    .button(title: "Run"),
                    .spacer,
                    .text("Ready")
                ])
            ])
        )
    }

    func testProviderReturnsDiagnosticForUnsupportedSource() throws {
        let result = try SwiftUIPreviewProvider().makePreview(
            PreviewRequest(
                files: [PreviewSourceFile(path: "main.swift", contents: "let value = 42")],
                entryFilePath: "main.swift"
            )
        )

        XCTAssertFalse(result.succeeded)
        XCTAssertNil(result.document)
        XCTAssertEqual(result.diagnostics.first?.severity, .error)
    }

    func testSwiftUIPreviewTemplateCreatesPreviewableSource() throws {
        let project = BuiltInProjectTemplates.swiftUIPreview.instantiate(
            projectIdentifier: "tests.preview",
            projectDisplayName: "Demo Preview"
        )

        let entry = try XCTUnwrap(project.descriptor.entryFilePath)
        let data = try XCTUnwrap(project.initialFiles[entry])
        let text = try XCTUnwrap(String(data: data, encoding: .utf8))

        XCTAssertTrue(text.contains("Demo Preview"))
        XCTAssertEqual(project.descriptor.attributes["projectKind"], "app-preview")

        let result = try SwiftUIFullScreenCoverItemPreviewProvider().makePreview(
            PreviewRequest(
                files: [PreviewSourceFile(path: entry.value, contents: text)],
                entryFilePath: entry.value
            )
        )
        XCTAssertTrue(result.succeeded)
    }
}
