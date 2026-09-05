import Foundation
import XCTest
@testable import iSwiftCode

final class PreviewItemPresentationTemplateTests: XCTestCase {
    private func templateSource() throws -> String {
        let project = BuiltInProjectTemplates
            .swiftUIPreview
            .instantiate(
                projectIdentifier:
                    "tests.item-presentation-template",
                projectDisplayName:
                    "Item Presentation Demo"
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

    func testTemplateContainsSeparateItemBindings() throws {
        let source = try templateSource()

        XCTAssertTrue(
            source.contains(
                "@State private var selectedSheetItem: String? = nil"
            )
        )
        XCTAssertTrue(
            source.contains(
                "@State private var selectedFullScreenItem: String? = nil"
            )
        )
    }

    func testTemplateContainsSheetItemDemo() throws {
        let source = try templateSource()

        XCTAssertTrue(
            source.contains(
                "Button(\"Open Item Sheet\")"
            )
        )
        XCTAssertTrue(
            source.contains(
                ".sheet(item: $selectedSheetItem)"
            )
        )
        XCTAssertTrue(
            source.contains(
                "Text(item)"
            )
        )
        XCTAssertTrue(
            source.contains(
                "selectedSheetItem = nil"
            )
        )
    }

    func testTemplateContainsFullScreenItemDemo() throws {
        let source = try templateSource()

        XCTAssertTrue(
            source.contains(
                "Button(\"Open Item Full Screen\")"
            )
        )
        XCTAssertTrue(
            source.contains(
                ".fullScreenCover(item: $selectedFullScreenItem)"
            )
        )
        XCTAssertTrue(
            source.contains(
                "selectedFullScreenItem = nil"
            )
        )
    }

    func testTemplateParsesThroughCurrentPresentationStack() throws {
        let result = try preview(
            templateSource()
        )

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

    func testTemplateLowersBothItemPresentationBindings() throws {
        let result = try preview(
            templateSource()
        )

        let root = try XCTUnwrap(
            result.document?.root
        )

        var sheetBindings = Set<String>()
        var fullScreenBindings = Set<String>()

        func walk(
            _ node: PreviewNode
        ) {
            switch node {
            case .modified(
                let base,
                let modifiers
            ):
                for modifier in modifiers {
                    switch modifier {
                    case .sheet(
                        let reference,
                        let content
                    ):
                        sheetBindings.insert(
                            reference.stateName
                        )
                        walk(content)

                    case .sheetWithOnDismiss(
                        let reference,
                        _,
                        let content
                    ):
                        sheetBindings.insert(
                            reference.stateName
                        )
                        walk(content)

                    case .fullScreenCover(
                        let reference,
                        let content
                    ):
                        fullScreenBindings.insert(
                            reference.stateName
                        )
                        walk(content)

                    case .fullScreenCoverWithOnDismiss(
                        let reference,
                        _,
                        let content
                    ):
                        fullScreenBindings.insert(
                            reference.stateName
                        )
                        walk(content)

                    default:
                        break
                    }
                }

                walk(base)

            case .vStack(let children),
                 .hStack(let children),
                 .zStack(let children),
                 .scrollView(let children),
                 .list(let children),
                 .navigationStack(let children):
                children.forEach(walk)

            case .navigationLink(
                _,
                let destination
            ):
                walk(destination)

            default:
                break
            }
        }

        walk(root)

        XCTAssertTrue(
            sheetBindings.contains(
                "selectedSheetItem"
            )
        )
        XCTAssertTrue(
            fullScreenBindings.contains(
                "selectedFullScreenItem"
            )
        )
    }
}
