import Foundation
import XCTest
@testable import iSwiftCode

final class PreviewSheetTemplateTests: XCTestCase {
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
                    entryFilePath: "ContentView.swift"
                )
            )
    }

    func testBuiltInTemplateContainsSheetDemo() throws {
        let project = BuiltInProjectTemplates
            .swiftUIPreview
            .instantiate(
                projectIdentifier: "tests.sheet-demo",
                projectDisplayName: "Sheet Demo"
            )

        let entry = try XCTUnwrap(
            project.descriptor.entryFilePath
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

        XCTAssertTrue(
            source.contains(
                "@State private var showingInfo = false"
            )
        )
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
                "showingInfo = false"
            )
        )
    }

    func testBuiltInTemplateStillProducesInteractivePreview() throws {
        let project = BuiltInProjectTemplates
            .swiftUIPreview
            .instantiate(
                projectIdentifier: "tests.sheet-preview",
                projectDisplayName: "Sheet Preview"
            )

        let entry = try XCTUnwrap(
            project.descriptor.entryFilePath
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

    func testSheetContentKeepsStateInterpolation() throws {
        let project = BuiltInProjectTemplates
            .swiftUIPreview
            .instantiate(
                projectIdentifier: "tests.sheet-state",
                projectDisplayName: "State Demo"
            )

        let entry = try XCTUnwrap(
            project.descriptor.entryFilePath
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
    }

    func testNavigationDemoStillExistsAlongsideSheet() throws {
        let project = BuiltInProjectTemplates
            .swiftUIPreview
            .instantiate(
                projectIdentifier: "tests.sheet-navigation",
                projectDisplayName: "Navigation and Sheet"
            )

        let entry = try XCTUnwrap(
            project.descriptor.entryFilePath
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
        XCTAssertTrue(
            source.contains(
                ".sheet(isPresented: $showingInfo)"
            )
        )
    }
}
