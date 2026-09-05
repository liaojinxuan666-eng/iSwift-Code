import Foundation
import XCTest
@testable import iSwiftCode

final class PreviewOptionalStateTests: XCTestCase {
    private func structuralPreview(
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
                    entryFilePath:
                        "ContentView.swift"
                )
            )
    }

    private func actionPreview(
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
                    entryFilePath:
                        "ContentView.swift"
                )
            )
    }

    func testTypedOptionalStringNilStateIsPreserved() throws {
        let result = try structuralPreview(
            """
            @State private var selectedItem: String? = nil

            Text(selectedItem)
            """
        )

        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(
            result.document?.stateDefinitions,
            [
                PreviewStateDefinition(
                    name: "selectedItem",
                    initialValue:
                        .optionalString(nil)
                )
            ]
        )
        XCTAssertEqual(
            result.document?.root,
            .stateText(
                name: "selectedItem"
            )
        )
    }

    func testTypedOptionalBoolAndNumberNilStatesArePreserved() throws {
        let result = try structuralPreview(
            """
            @State private var flag: Bool? = nil
            @State private var count: Int? = nil

            VStack {
                Text(flag)
                Text(count)
            }
            """
        )

        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(
            result.document?
                .stateDefinitions,
            [
                PreviewStateDefinition(
                    name: "flag",
                    initialValue:
                        .optionalBool(nil)
                ),
                PreviewStateDefinition(
                    name: "count",
                    initialValue:
                        .optionalNumber(nil)
                )
            ]
        )
    }

    func testButtonCanSetOptionalStringItem() throws {
        let result = try actionPreview(
            """
            @State private var selectedItem: String? = nil

            Button("Open") {
                selectedItem = "Details"
            }
            """
        )

        XCTAssertTrue(result.succeeded)

        guard case .actionButton(
            _,
            let program
        ) = result.document?.root else {
            return XCTFail(
                "Expected action button."
            )
        }

        XCTAssertEqual(
            program,
            PreviewActionProgram(
                actions: [
                    .set(
                        stateName:
                            "selectedItem",
                        value:
                            .string("Details")
                    )
                ]
            )
        )
    }

    func testButtonCanClearOptionalItemWithNil() throws {
        let result = try actionPreview(
            """
            @State private var selectedItem: String? = nil

            Button("Close") {
                selectedItem = nil
            }
            """
        )

        XCTAssertTrue(result.succeeded)

        guard case .actionButton(
            _,
            let program
        ) = result.document?.root else {
            return XCTFail(
                "Expected action button."
            )
        }

        XCTAssertEqual(
            program,
            PreviewActionProgram(
                actions: [
                    .clear(
                        stateName:
                            "selectedItem"
                    )
                ]
            )
        )
    }

    func testOptionalStateSetAndClearRoundTripInRuntimeStore() {
        let store = PreviewStateStore(
            definitions: [
                PreviewStateDefinition(
                    name: "selectedItem",
                    initialValue:
                        .optionalString(nil)
                )
            ]
        )

        XCTAssertNil(
            store.optionalItemValue(
                for: "selectedItem"
            )
        )

        XCTAssertTrue(
            store.perform(
                PreviewActionProgram(
                    actions: [
                        .set(
                            stateName:
                                "selectedItem",
                            value:
                                .string("Details")
                        )
                    ]
                )
            )
        )

        XCTAssertEqual(
            store.value(
                for: "selectedItem"
            ),
            .optionalString("Details")
        )
        XCTAssertEqual(
            store.optionalItemValue(
                for: "selectedItem"
            ),
            .string("Details")
        )

        XCTAssertTrue(
            store.perform(
                PreviewActionProgram(
                    actions: [
                        .clear(
                            stateName:
                                "selectedItem"
                        )
                    ]
                )
            )
        )

        XCTAssertEqual(
            store.value(
                for: "selectedItem"
            ),
            .optionalString(nil)
        )
    }

    func testClearIsRejectedForNonOptionalState() throws {
        let result = try actionPreview(
            """
            @State private var title = "Ready"

            Button("Clear") {
                title = nil
            }
            """
        )

        XCTAssertFalse(result.succeeded)
        XCTAssertNil(result.document)
        XCTAssertTrue(
            result.diagnostics.first?
                .message
                .contains("clear") == true
        )
    }

    func testOptionalStringRejectsNumberAssignment() throws {
        let result = try actionPreview(
            """
            @State private var selectedItem: String? = nil

            Button("Bad") {
                selectedItem = 42
            }
            """
        )

        XCTAssertFalse(result.succeeded)
        XCTAssertNil(result.document)
        XCTAssertTrue(
            result.diagnostics.first?
                .message
                .contains("incompatible") == true
        )
    }
}
