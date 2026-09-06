import Foundation
import XCTest
@testable import iSwiftCode

final class PreviewControlContentTests:
    XCTestCase {
    private func preview(
        _ source: String
    ) throws -> PreviewProviderResult {
        try SwiftUIControlContentPreviewProvider()
            .makePreview(
                PreviewRequest(
                    files: [
                        PreviewSourceFile(
                            path:
                                "ContentView.swift",
                            contents:
                                source
                        )
                    ],
                    entryFilePath:
                        "ContentView.swift"
                )
            )
    }

    func testStandaloneLabelLowers() throws {
        let result = try preview(
            """
            Label("Settings", systemImage: "gear")
            """
        )

        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(
            result.document?.root,
            .label(
                title: "Settings",
                systemName: "gear"
            )
        )
    }

    func testRoleActionButtonPreservesProgram() throws {
        let result = try preview(
            """
            @State private var count = 2

            Button("Delete", role: .destructive) {
                count -= 1
            }
            """
        )

        XCTAssertTrue(result.succeeded)

        guard case .roleActionButton(
            let title,
            let role,
            let program
        ) = result.document?.root else {
            return XCTFail(
                "Expected roleActionButton"
            )
        }

        XCTAssertEqual(title, "Delete")
        XCTAssertEqual(role, .destructive)
        XCTAssertFalse(program.actions.isEmpty)
    }

    func testLabelActionButtonLowers() throws {
        let result = try preview(
            """
            @State private var count = 0

            Button {
                count += 1
            } label: {
                Label("Build", systemImage: "hammer")
            }
            """
        )

        XCTAssertTrue(result.succeeded)

        guard case .labelActionButton(
            let title,
            let systemName,
            let role,
            let program
        ) = result.document?.root else {
            return XCTFail(
                "Expected labelActionButton"
            )
        }

        XCTAssertEqual(title, "Build")
        XCTAssertEqual(systemName, "hammer")
        XCTAssertNil(role)
        XCTAssertFalse(program.actions.isEmpty)
    }

    func testRoleLabelActionButtonLowers() throws {
        let result = try preview(
            """
            @State private var enabled = true

            Button(role: .cancel) {
                enabled.toggle()
            } label: {
                Label("Cancel", systemImage: "xmark")
            }
            """
        )

        XCTAssertTrue(result.succeeded)

        guard case .labelActionButton(
            let title,
            let systemName,
            let role,
            _
        ) = result.document?.root else {
            return XCTFail(
                "Expected role label action button"
            )
        }

        XCTAssertEqual(title, "Cancel")
        XCTAssertEqual(systemName, "xmark")
        XCTAssertEqual(role, .cancel)
    }

    func testLabelStyleAndLiteralDisabledLower() throws {
        let result = try preview(
            """
            Label("Settings", systemImage: "gear")
                .labelStyle(.iconOnly)
                .disabled(true)
            """
        )

        XCTAssertTrue(result.succeeded)

        guard case .modified(
            let base,
            let modifiers
        ) = result.document?.root else {
            return XCTFail(
                "Expected modified Label"
            )
        }

        XCTAssertEqual(
            base,
            .label(
                title: "Settings",
                systemName: "gear"
            )
        )
        XCTAssertTrue(
            modifiers.contains(
                .labelStyle(.iconOnly)
            )
        )
        XCTAssertTrue(
            modifiers.contains(
                .disabled(.literal(true))
            )
        )
    }

    func testStateDrivenDisabledRequiresBoolState() throws {
        let valid = try preview(
            """
            @State private var locked = true

            Button("Build") {}
                .disabled(locked)
            """
        )

        XCTAssertTrue(valid.succeeded)

        let invalid = try preview(
            """
            @State private var title = "Locked"

            Button("Build") {}
                .disabled(title)
            """
        )

        XCTAssertFalse(invalid.succeeded)
        XCTAssertTrue(
            invalid.diagnostics
                .first?
                .message
                .contains("Bool") == true
        )
    }

    func testRichSyntaxInsideStringsAndCommentsIsIgnored() throws {
        let source =
            """
            Text("Label(\\"Fake\\", systemImage: \\"gear\\")")
            // Button("Delete", role: .destructive) {}
            // .disabled(true)
            """

        let rewrite =
            try PreviewControlContentSourceRewriter(
                source: source
            ).rewrite()

        XCTAssertFalse(rewrite.hasChanges)
        XCTAssertEqual(rewrite.source, source)
    }
}
