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
        try SwiftUIFullScreenCoverPreviewProvider()
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
                ".fullScreenCover(isPresented: $showingFullScreen)"
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
                "showingFullScreen"
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

    func testFullScreenDemoLowersToPortableModifier() throws {
        let source = try templateSource()
        let result = try preview(source)

        XCTAssertTrue(result.succeeded)

        func containsFullScreenCover(
            _ node: PreviewNode
        ) -> Bool {
            switch node {
            case .modified(
                let base,
                let modifiers
            ):
                if modifiers.contains(
                    where: { modifier in
                        if case .fullScreenCover = modifier {
                            return true
                        }

                        return false
                    }
                ) {
                    return true
                }

                return containsFullScreenCover(base)

            case .vStack(let children),
                 .hStack(let children),
                 .zStack(let children),
                 .scrollView(let children),
                 .list(let children),
                 .navigationStack(let children):
                return children.contains(
                    where: containsFullScreenCover
                )

            case .navigationLink(
                _,
                let destination
            ):
                return containsFullScreenCover(
                    destination
                )

            default:
                return false
            }
        }

        let root = try XCTUnwrap(
            result.document?.root
        )
        XCTAssertTrue(
            containsFullScreenCover(root)
        )
    }
}
