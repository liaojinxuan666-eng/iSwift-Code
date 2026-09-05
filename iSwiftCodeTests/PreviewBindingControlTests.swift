import Foundation
import XCTest
@testable import iSwiftCode

final class PreviewBindingControlTests: XCTestCase {
    private func preview(
        _ source: String
    ) throws -> PreviewProviderResult {
        try SwiftUIPreviewProvider()
            .makePreview(
                PreviewRequest(
                    files: [
                        PreviewSourceFile(
                            path: "ContentView.swift",
                            contents: source
                        )
                    ],
                    entryFilePath: "ContentView.swift"
                )
            )
    }

    func testTextFieldPreservesBindingReference() throws {
        let result = try preview(
            """
            @State private var name = "Guest"

            TextField("Name", text: $name)
            """
        )

        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(
            result.document?.root,
            .textField(
                prompt: "Name",
                text: PreviewBindingReference(
                    stateName: "name"
                )
            )
        )
    }

    func testTogglePreservesBindingReference() throws {
        let result = try preview(
            """
            @State private var enabled = true

            Toggle("Enabled", isOn: $enabled)
            """
        )

        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(
            result.document?.root,
            .toggle(
                title: "Enabled",
                isOn: PreviewBindingReference(
                    stateName: "enabled"
                )
            )
        )
    }

    func testControlsCanBeNestedWithStateBackedText() throws {
        let result = try preview(
            """
            @State private var name = "Guest"
            @State private var enabled = false

            VStack(spacing: 12) {
                TextField("Name", text: $name)
                Toggle("Enabled", isOn: $enabled)
                Text("Hello, \\(name)")
                Text("Enabled: \\(enabled)")
            }
            """
        )

        XCTAssertTrue(result.succeeded)
        XCTAssertNotNil(result.document)
    }

    func testUnknownStateBindingProducesDiagnostic() throws {
        let result = try preview(
            """
            TextField("Name", text: $missing)
            """
        )

        XCTAssertFalse(result.succeeded)
        XCTAssertNil(result.document)
        XCTAssertEqual(
            result.diagnostics.first?.severity,
            .error
        )
        XCTAssertTrue(
            result.diagnostics.first?.message
                .contains("missing") == true
        )
    }

    func testStateStoreProvidesTypedControlValues() {
        let store = PreviewStateStore(
            definitions: [
                PreviewStateDefinition(
                    name: "name",
                    initialValue: .string("Guest")
                ),
                PreviewStateDefinition(
                    name: "enabled",
                    initialValue: .bool(false)
                )
            ]
        )

        XCTAssertEqual(
            store.stringValue(for: "name"),
            "Guest"
        )
        XCTAssertFalse(
            store.boolValue(for: "enabled")
        )

        store.setValue(
            .string("Alice"),
            for: "name"
        )
        store.setValue(
            .bool(true),
            for: "enabled"
        )

        XCTAssertEqual(
            store.stringValue(for: "name"),
            "Alice"
        )
        XCTAssertTrue(
            store.boolValue(for: "enabled")
        )
        XCTAssertEqual(
            store.resolveInterpolations(
                in: "Hello, \\(name)"
            ),
            "Hello, Alice"
        )
    }

    func testBuiltInTemplateContainsInteractiveControls() throws {
        let project = BuiltInProjectTemplates
            .swiftUIPreview
            .instantiate(
                projectIdentifier: "tests.preview-controls",
                projectDisplayName: "Controls Preview"
            )

        let entry = try XCTUnwrap(
            project.descriptor.entryFilePath
        )
        let data = try XCTUnwrap(
            project.initialFiles[entry]
        )
        let source = try XCTUnwrap(
            String(data: data, encoding: .utf8)
        )

        XCTAssertTrue(source.contains("TextField"))
        XCTAssertTrue(source.contains("Toggle"))

        let result = try SwiftUIFullScreenCoverItemPreviewProvider()
            .makePreview(
                PreviewRequest(
                    files: [
                        PreviewSourceFile(
                            path: entry.value,
                            contents: source
                        )
                    ],
                    entryFilePath: entry.value
                )
            )
        XCTAssertTrue(result.succeeded)
    }
}
