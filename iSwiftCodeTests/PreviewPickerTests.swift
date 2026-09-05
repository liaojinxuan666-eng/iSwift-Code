import Foundation
import XCTest
@testable import iSwiftCode

final class PreviewPickerTests: XCTestCase {
    private func preview(
        _ source: String
    ) throws -> PreviewProviderResult {
        try SwiftUIInteractivePreviewProvider()
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

    func testStringPickerLowersToPortablePickerIR() throws {
        let result = try preview(
            """
            @State private var mode = "preview"

            Picker("Mode", selection: $mode) {
                Text("Preview").tag("preview")
                Text("Console").tag("console")
            }
            """
        )

        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(
            result.document?.root,
            .picker(
                title: "Mode",
                selection:
                    PreviewBindingReference(
                        stateName: "mode"
                    ),
                options: [
                    PreviewPickerOption(
                        title: "Preview",
                        value:
                            .string("preview")
                    ),
                    PreviewPickerOption(
                        title: "Console",
                        value:
                            .string("console")
                    )
                ]
            )
        )
    }

    func testNumberPickerSupportsNumericTags() throws {
        let result = try preview(
            """
            @State private var tab = 0

            Picker("Tab", selection: $tab) {
                Text("First").tag(0)
                Text("Second").tag(1)
            }
            """
        )

        XCTAssertTrue(result.succeeded)

        guard case .picker(
            let title,
            let selection,
            let options
        ) = result.document?.root else {
            return XCTFail(
                "Expected picker root."
            )
        }

        XCTAssertEqual(title, "Tab")
        XCTAssertEqual(
            selection.stateName,
            "tab"
        )
        XCTAssertEqual(
            options.map(\.value),
            [
                .number(0),
                .number(1)
            ]
        )
    }

    func testNestedPickerPreservesExistingModifiers() throws {
        let result = try preview(
            """
            @State private var mode = "preview"

            VStack(spacing: 12) {
                Text("Choose mode")

                Picker("Mode", selection: $mode) {
                    Text("Preview").tag("preview")
                    Text("Console").tag("console")
                }
                .padding(8)

                Text("Mode: \(mode)")
            }
            """
        )

        XCTAssertTrue(result.succeeded)

        guard case .modified(
            let rootBase,
            _
        ) = result.document?.root,
        case .vStack(let children) =
            rootBase else {
            return XCTFail(
                "Expected modified VStack root."
            )
        }

        XCTAssertEqual(children.count, 3)

        guard case .modified(
            let pickerBase,
            let modifiers
        ) = children[1],
        case .picker = pickerBase else {
            return XCTFail(
                "Expected modified picker."
            )
        }

        XCTAssertEqual(
            modifiers,
            [.padding(8)]
        )
    }

    func testUnknownPickerSelectionStateProducesDiagnostic() throws {
        let result = try preview(
            """
            Picker("Mode", selection: $missing) {
                Text("Preview").tag("preview")
                Text("Console").tag("console")
            }
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

    func testPickerTagTypeMustMatchSelectionState() throws {
        let result = try preview(
            """
            @State private var tab = 0

            Picker("Tab", selection: $tab) {
                Text("First").tag("first")
                Text("Second").tag("second")
            }
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
                .contains("match") == true
        )
    }

    func testNonPickerSourceStillUsesBaselineProvider() throws {
        let result = try preview(
            """
            @State private var name = "Guest"

            VStack {
                TextField("Name", text: $name)
                Text("Hello, \(name)")
            }
            """
        )

        XCTAssertTrue(result.succeeded)
        XCTAssertNotNil(result.document)
    }
}
