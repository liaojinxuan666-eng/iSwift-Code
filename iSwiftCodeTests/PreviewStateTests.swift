import Foundation
import XCTest
@testable import iSwiftCode

final class PreviewStateTests: XCTestCase {
    private func preview(
        _ source: String
    ) throws -> PreviewProviderResult {
        try SwiftUIPreviewProvider()
            .makePreview(
                PreviewRequest(
                    files: [
                        PreviewSourceFile(
                            path:
                                "ContentView.swift",
                            contents: source
                        )
                    ],
                    entryFilePath:
                        "ContentView.swift"
                )
            )
    }

    func testPrimitiveStateDefinitionsArePreserved() throws {
        let result = try preview(
            """
            @State private var title = "Ready"
            @State var enabled = true
            @State private var progress: Double = 0.5

            VStack {
                Text(title)
                Text("Enabled: \\(enabled)")
            }
            """
        )

        XCTAssertEqual(
            result.document?.stateDefinitions,
            [
                PreviewStateDefinition(
                    name: "title",
                    initialValue:
                        .string("Ready")
                ),
                PreviewStateDefinition(
                    name: "enabled",
                    initialValue:
                        .bool(true)
                ),
                PreviewStateDefinition(
                    name: "progress",
                    initialValue:
                        .number(0.5)
                )
            ]
        )
    }

    func testTextCanReferenceStringStateDirectly() throws {
        let result = try preview(
            """
            @State private var title = "Hello"

            Text(title)
            """
        )

        XCTAssertEqual(
            result.document?.root,
            .stateText(name: "title")
        )
    }

    func testTextInterpolationIsPreservedForRuntimeResolution() throws {
        let result = try preview(
            """
            @State private var count = 42

            Text("Count: \\(count)")
            """
        )

        XCTAssertEqual(
            result.document?.root,
            .interpolatedText(
                "Count: \\(count)"
            )
        )
    }

    func testStateTextCanStillUseModifiers() throws {
        let result = try preview(
            """
            @State private var status = "Ready"

            Text(status)
                .font(.headline)
                .foregroundStyle(.green)
            """
        )

        XCTAssertEqual(
            result.document?.root,
            .modified(
                base:
                    .stateText(
                        name: "status"
                    ),
                modifiers: [
                    .font(.headline),
                    .foregroundStyle(.green)
                ]
            )
        )
    }

    func testStateStoreResolvesAndMutatesValues() {
        let store = PreviewStateStore(
            definitions: [
                PreviewStateDefinition(
                    name: "status",
                    initialValue:
                        .string("Ready")
                ),
                PreviewStateDefinition(
                    name: "count",
                    initialValue:
                        .number(1)
                )
            ]
        )

        XCTAssertEqual(
            store.displayText(
                for: "status"
            ),
            "Ready"
        )

        XCTAssertEqual(
            store.resolveInterpolations(
                in:
                    "Status: \\(status), count: \\(count)"
            ),
            "Status: Ready, count: 1"
        )

        store.setValue(
            .number(2),
            for: "count"
        )

        XCTAssertEqual(
            store.resolveInterpolations(
                in: "Count: \\(count)"
            ),
            "Count: 2"
        )
    }

    func testStateStoreReloadResetsToSourceDefinitions() {
        let store = PreviewStateStore(
            definitions: [
                PreviewStateDefinition(
                    name: "status",
                    initialValue:
                        .string("Old")
                )
            ]
        )

        store.setValue(
            .string("Changed"),
            for: "status"
        )

        store.reload(
            definitions: [
                PreviewStateDefinition(
                    name: "status",
                    initialValue:
                        .string("New")
                )
            ]
        )

        XCTAssertEqual(
            store.displayText(
                for: "status"
            ),
            "New"
        )
    }

    func testBuiltInTemplateProducesStateAwarePreview() throws {
        let project =
            BuiltInProjectTemplates
                .swiftUIPreview
                .instantiate(
                    projectIdentifier:
                        "tests.preview-state",
                    projectDisplayName:
                        "State Preview"
                )

        let entry = try XCTUnwrap(
            project.descriptor
                .entryFilePath
        )

        let data = try XCTUnwrap(
            project.initialFiles[entry]
        )

        let source = try XCTUnwrap(
            String(
                data: data,
                encoding: .utf8
            )
        )

        let result = try preview(source)

        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(
            result.document?
                .stateDefinitions
                .map(\.name),
            [
                "status",
                "count",
                "name",
                "enabled"
            ]
        )
    }
}
