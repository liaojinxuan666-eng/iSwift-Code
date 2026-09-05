import Foundation
import XCTest
@testable import iSwiftCode

final class PreviewFullScreenCoverTemplateTests: XCTestCase {
    private func templateSource(
        displayName: String = "Full Screen Demo"
    ) throws -> String {
        let project = BuiltInProjectTemplates
            .swiftUIPreview
            .instantiate(
                projectIdentifier:
                    "tests.full-screen-template",
                projectDisplayName:
                    displayName
            )

        let entry = try XCTUnwrap(
            project.descriptor.entryFilePath
        )
        let data = try XCTUnwrap(
            project.initialFiles[entry]
        )

        return try XCTUnwrap(
            String(
                data: data,
                encoding: .utf8
            )
        )
    }

    private func preview(
        _ source: String
    ) throws -> PreviewProviderResult {
        try SwiftUIFullScreenCoverItemPreviewProvider()
            .makePreview(
                PreviewRequest(
                    files: [
                        PreviewSourceFile(
                            path: "ContentView.swift",
                            contents: source
                        )
                    ],
                    entryFilePath:
                        "ContentView.swift"
                )
            )
    }

    func testBuiltInTemplateContainsFullScreenDemo() throws {
        let source = try templateSource()

        XCTAssertTrue(
            source.contains(
                "@State private var showingFullScreen = false"
            )
        )
        XCTAssertTrue(
            source.contains(
                "Button(\"Open Full Screen\")"
            )
        )
        XCTAssertTrue(
            source.contains(
                "isPresented: $showingFullScreen"
            )
        )
        XCTAssertTrue(
            source.contains(
                "onDismiss: {"
            )
        )
        XCTAssertTrue(
            source.contains(
                "status = \"Full Screen Closed\""
            )
        )
        XCTAssertTrue(
            source.contains(
                "Button(\"Close Full Screen\")"
            )
        )
        XCTAssertTrue(
            source.contains(
                "showingFullScreen = false"
            )
        )
    }

    func testBuiltInTemplateStillProducesTopLevelInteractivePreview() throws {
        let source = try templateSource(
            displayName: "Presentation Demo"
        )
        let result = try preview(source)

        XCTAssertTrue(result.succeeded)
        XCTAssertNotNil(result.document)
        XCTAssertEqual(
            result.document?
                .stateDefinitions
                .map(\.name),
            [
                "status",
                "count",
                "name",
                "enabled",
                "showingInfo",
                "showingFullScreen",
                "selectedSheetItem",
                "selectedFullScreenItem"
            ]
        )
    }

    func testTemplateStillContainsSheetAndNavigationExamples() throws {
        let source = try templateSource()

        XCTAssertTrue(
            source.contains(
                "Button(\"Open Sheet\")"
            )
        )
        XCTAssertTrue(
            source.contains(
                ".sheet(isPresented: $showingInfo)"
            )
        )
        XCTAssertTrue(
            source.contains(
                "NavigationLink(\"Open Details\")"
            )
        )
        XCTAssertTrue(
            source.contains(
                ".navigationTitle(\"Details\")"
            )
        )
    }

    func testFullScreenContentKeepsStateInterpolationEscaping() throws {
        let source = try templateSource()

        XCTAssertTrue(
            source.contains(
                "Text(\"Hello, \\(name)\")"
            )
        )
        XCTAssertTrue(
            source.contains(
                "Text(\"Count: \\(count)\")"
            )
        )

        let result = try preview(source)
        XCTAssertTrue(result.succeeded)
    }

    func testFullScreenDemoLowersToOnDismissPortableModifier() throws {
        let source = try templateSource()
        let result = try preview(source)

        XCTAssertTrue(result.succeeded)

        func fullScreenProgram(
            in node: PreviewNode
        ) -> PreviewActionProgram? {
            switch node {
            case .modified(
                let base,
                let modifiers
            ):
                for modifier in modifiers {
                    if case .fullScreenCoverWithOnDismiss(
                        _,
                        let program,
                        _
                    ) = modifier {
                        return program
                    }
                }

                return fullScreenProgram(
                    in: base
                )

            case .vStack(let children),
                 .hStack(let children),
                 .zStack(let children),
                 .scrollView(let children),
                 .list(let children),
                 .navigationStack(let children):
                for child in children {
                    if let program =
                        fullScreenProgram(in: child) {
                        return program
                    }
                }

                return nil

            case .navigationLink(
                _,
                let destination
            ):
                return fullScreenProgram(
                    in: destination
                )

            default:
                return nil
            }
        }

        let root = try XCTUnwrap(
            result.document?.root
        )
        let program = try XCTUnwrap(
            fullScreenProgram(in: root)
        )

        XCTAssertEqual(
            program,
            PreviewActionProgram(
                actions: [
                    .set(
                        stateName: "status",
                        value:
                            .string(
                                "Full Screen Closed"
                            )
                    )
                ]
            )
        )
    }
}
