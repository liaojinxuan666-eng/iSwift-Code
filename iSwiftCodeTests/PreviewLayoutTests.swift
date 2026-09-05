import Foundation
import XCTest
@testable import iSwiftCode

final class PreviewLayoutTests: XCTestCase {
    private func preview(_ source: String) throws -> PreviewProviderResult {
        try SwiftUIPreviewProvider().makePreview(
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

    func testVStackAlignmentAndSpacingArePreserved() throws {
        let result = try preview(
            """
            VStack(alignment: .leading, spacing: 16) {
                Text("One")
                Text("Two")
            }
            """
        )

        XCTAssertEqual(
            result.document?.root,
            .modified(
                base: .vStack(
                    children: [
                        .text("One"),
                        .text("Two")
                    ]
                ),
                modifiers: [
                    .horizontalAlignment(.leading),
                    .stackSpacing(16)
                ]
            )
        )
    }

    func testHStackVerticalAlignmentAndSpacingArePreserved() throws {
        let result = try preview(
            """
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Title")
                Text("Caption")
            }
            """
        )

        XCTAssertEqual(
            result.document?.root,
            .modified(
                base: .hStack(
                    children: [
                        .text("Title"),
                        .text("Caption")
                    ]
                ),
                modifiers: [
                    .verticalAlignment(.firstTextBaseline),
                    .stackSpacing(8)
                ]
            )
        )
    }

    func testZStackAlignmentIsPreserved() throws {
        let result = try preview(
            """
            ZStack(alignment: .topTrailing) {
                Text("Background")
                Text("Badge")
            }
            """
        )

        XCTAssertEqual(
            result.document?.root,
            .modified(
                base: .zStack(
                    children: [
                        .text("Background"),
                        .text("Badge")
                    ]
                ),
                modifiers: [
                    .zStackAlignment(.topTrailing)
                ]
            )
        )
    }

    func testExplicitViewModifiersRemainAfterLayoutModifiers() throws {
        let result = try preview(
            """
            VStack(alignment: .trailing, spacing: 10) {
                Text("Hello")
            }
            .padding(20)
            .background(.blue)
            """
        )

        XCTAssertEqual(
            result.document?.root,
            .modified(
                base: .vStack(
                    children: [
                        .text("Hello")
                    ]
                ),
                modifiers: [
                    .horizontalAlignment(.trailing),
                    .stackSpacing(10),
                    .padding(20),
                    .background(.blue)
                ]
            )
        )
    }

    func testInvalidStackAlignmentProducesDiagnostic() throws {
        let result = try preview(
            """
            VStack(alignment: .top, spacing: 12) {
                Text("Invalid")
            }
            """
        )

        XCTAssertFalse(result.succeeded)
        XCTAssertNil(result.document)
        XCTAssertEqual(
            result.diagnostics.first?.severity,
            .error
        )
    }

    func testBuiltInPreviewTemplateUsesLayoutIR() throws {
        let project = BuiltInProjectTemplates.swiftUIPreview.instantiate(
            projectIdentifier: "tests.preview-layout",
            projectDisplayName: "Layout Preview"
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

        let result = try preview(source)

        XCTAssertTrue(result.succeeded)
        XCTAssertNotNil(result.document)
    }
}
