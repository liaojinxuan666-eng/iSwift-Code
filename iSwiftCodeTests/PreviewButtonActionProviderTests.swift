import Foundation
import XCTest
@testable import iSwiftCode

final class PreviewButtonActionProviderTests: XCTestCase {
    private func preview(
        _ source: String
    ) throws -> PreviewProviderResult {
        try SwiftUIButtonActionPreviewProvider()
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

    func testAddButtonLowersToActionIR() throws {
        let result = try preview(
            """
            @State private var count = 0

            Button("Add") {
                count += 1
            }
            """
        )

        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(
            result.document?.root,
            .actionButton(
                title: "Add",
                program: PreviewActionProgram(
                    actions: [
                        .add(
                            stateName: "count",
                            amount: 1
                        )
                    ]
                )
            )
        )
    }

    func testToggleAndSetActionsLowerInOrder() throws {
        let result = try preview(
            """
            @State private var enabled = false
            @State private var status = "Ready"

            Button("Apply") {
                enabled.toggle()
                status = "Done"
            }
            """
        )

        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(
            result.document?.root,
            .actionButton(
                title: "Apply",
                program: PreviewActionProgram(
                    actions: [
                        .toggle(stateName: "enabled"),
                        .set(
                            stateName: "status",
                            value: .string("Done")
                        )
                    ]
                )
            )
        )
    }

    func testSubtractLowersToNegativeAdd() throws {
        let result = try preview(
            """
            @State private var count = 5

            Button("Remove") {
                count -= 2
            }
            """
        )

        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(
            result.document?.root,
            .actionButton(
                title: "Remove",
                program: PreviewActionProgram(
                    actions: [
                        .add(
                            stateName: "count",
                            amount: -2
                        )
                    ]
                )
            )
        )
    }

    func testActionButtonKeepsViewModifiers() throws {
        let result = try preview(
            """
            @State private var count = 0

            Button("Add") {
                count += 1
            }
            .padding(8)
            """
        )

        XCTAssertTrue(result.succeeded)

        guard case .modified(
            let base,
            let modifiers
        ) = result.document?.root else {
            return XCTFail("Expected modified action button.")
        }

        guard case .actionButton = base else {
            return XCTFail("Expected action button base.")
        }

        let expected: [PreviewModifier] = [
            .padding(8)
        ]
        XCTAssertEqual(modifiers, expected)
    }

    func testUnknownStateActionProducesDiagnostic() throws {
        let result = try preview(
            """
            Button("Add") {
                missing += 1
            }
            """
        )

        XCTAssertFalse(result.succeeded)
        XCTAssertNil(result.document)
        XCTAssertTrue(
            result.diagnostics.first?.message
                .contains("missing") == true
        )
    }

    func testIncompatibleActionProducesDiagnostic() throws {
        let result = try preview(
            """
            @State private var name = "Guest"

            Button("Add") {
                name += 1
            }
            """
        )

        XCTAssertFalse(result.succeeded)
        XCTAssertNil(result.document)
        XCTAssertTrue(
            result.diagnostics.first?.message
                .contains("incompatible") == true
        )
    }

    func testUnsupportedClosureIsRejectedInsteadOfExecuted() throws {
        let result = try preview(
            """
            @State private var count = 0

            Button("Run") {
                print("unsafe")
            }
            """
        )

        XCTAssertFalse(result.succeeded)
        XCTAssertNil(result.document)
        XCTAssertTrue(
            result.diagnostics.first?.message
                .contains("unsupported") == true
        )
    }

    func testEmptyButtonRemainsLegacyPreviewButton() throws {
        let result = try preview(
            """
            Button("Run") { }
            """
        )

        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(
            result.document?.root,
            .button(title: "Run")
        )
    }

    func testPickerAndActionButtonCanCoexist() throws {
        let result = try preview(
            """
            @State private var mode = "preview"
            @State private var count = 0

            VStack {
                Picker("Mode", selection: $mode) {
                    Text("Preview").tag("preview")
                    Text("Console").tag("console")
                }

                Button("Add") {
                    count += 1
                }

                Text("Count: \\(count)")
            }
            """
        )

        XCTAssertTrue(result.succeeded)
        XCTAssertNotNil(result.document)
    }

    func testBuiltInTemplateHasActionableButtons() throws {
        let project = BuiltInProjectTemplates
            .swiftUIPreview
            .instantiate(
                projectIdentifier: "tests.action-template",
                projectDisplayName: "Action Preview"
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

        XCTAssertTrue(source.contains("count += 1"))
        XCTAssertTrue(source.contains("enabled.toggle()"))

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
