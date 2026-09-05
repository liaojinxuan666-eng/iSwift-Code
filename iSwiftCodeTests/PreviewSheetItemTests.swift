import Foundation
import XCTest
@testable import iSwiftCode

final class PreviewSheetItemTests: XCTestCase {
    private func preview(
        _ source: String
    ) throws -> PreviewProviderResult {
        try SwiftUISheetItemPreviewProvider()
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

    func testOptionalStringSheetItemLowersToPortableSheet() throws {
        let result = try preview(
            """
            @State private var selectedItem: String? = nil

            Button("Open") {
                selectedItem = "Details"
            }
            .sheet(item: $selectedItem) { item in
                Text(item)
            }
            """
        )

        XCTAssertTrue(result.succeeded)

        guard case .modified(
            let base,
            let modifiers
        ) = result.document?.root,
        case .actionButton = base,
        case .sheet(
            let reference,
            let content
        ) = modifiers.first else {
            return XCTFail(
                "Expected action Button with item-driven portable sheet."
            )
        }

        XCTAssertEqual(
            reference.stateName,
            "selectedItem"
        )
        XCTAssertEqual(
            content,
            .stateText(name: "selectedItem")
        )
    }

    func testSheetItemContentCanClearOptionalState() throws {
        let result = try preview(
            """
            @State private var selectedItem: String? = nil

            Button("Open") {
                selectedItem = "Details"
            }
            .sheet(item: $selectedItem) { item in
                VStack {
                    Text(item)

                    Button("Close") {
                        selectedItem = nil
                    }
                }
            }
            """
        )

        XCTAssertTrue(result.succeeded)

        guard case .modified(
            _,
            let modifiers
        ) = result.document?.root,
        case .sheet(
            _,
            let content
        ) = modifiers.first,
        case .vStack(let children) = content,
        children.count == 2,
        case .actionButton(
            let title,
            let program
        ) = children[1] else {
            return XCTFail(
                "Expected constrained Close action inside item sheet."
            )
        }

        XCTAssertEqual(title, "Close")
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

    func testSheetItemInterpolationUsesOptionalStateValue() throws {
        let result = try preview(
            #"""
            @State private var selectedItem: String? = nil

            Text("Root")
                .sheet(item: $selectedItem) { item in
                    Text("Selected: \(item)")
                }
            """#
        )

        XCTAssertTrue(result.succeeded)

        guard case .modified(
            _,
            let modifiers
        ) = result.document?.root,
        case .sheet(
            _,
            let content
        ) = modifiers.first else {
            return XCTFail(
                "Expected item-driven sheet modifier."
            )
        }

        XCTAssertEqual(
            content,
            .interpolatedText(
                "Selected: \\(selectedItem)"
            )
        )
    }

    func testOptionalBoolAndNumberItemBindingsAreAccepted() throws {
        let boolResult = try preview(
            """
            @State private var selectedFlag: Bool? = nil

            Text("Root")
                .sheet(item: $selectedFlag) { item in
                    Text(item)
                }
            """
        )

        let numberResult = try preview(
            """
            @State private var selectedNumber: Int? = nil

            Text("Root")
                .sheet(item: $selectedNumber) { item in
                    Text(item)
                }
            """
        )

        XCTAssertTrue(boolResult.succeeded)
        XCTAssertTrue(numberResult.succeeded)
    }

    func testUnknownItemStateProducesDiagnostic() throws {
        let result = try preview(
            """
            Text("Root")
                .sheet(item: $missing) { item in
                    Text(item)
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

    func testNonOptionalStateIsRejectedForSheetItem() throws {
        let result = try preview(
            """
            @State private var selectedItem = "Details"

            Text("Root")
                .sheet(item: $selectedItem) { item in
                    Text(item)
                }
            """
        )

        XCTAssertFalse(result.succeeded)
        XCTAssertNil(result.document)
        XCTAssertTrue(
            result.diagnostics.first?.message
                .contains("optional") == true
        )
    }

    func testExistingBoolSheetStillFallsThrough() throws {
        let result = try preview(
            """
            @State private var showingInfo = false

            Button("Open") {
                showingInfo = true
            }
            .sheet(isPresented: $showingInfo) {
                Text("Info")
            }
            """
        )

        XCTAssertTrue(result.succeeded)

        guard case .modified(
            _,
            let modifiers
        ) = result.document?.root,
        case .sheet(
            let reference,
            _
        ) = modifiers.first else {
            return XCTFail(
                "Expected existing Bool sheet to remain supported."
            )
        }

        XCTAssertEqual(
            reference.stateName,
            "showingInfo"
        )
    }

    func testSheetItemInsideNavigationDestination() throws {
        let result = try preview(
            """
            @State private var selectedItem: String? = nil

            NavigationStack {
                NavigationLink("Details") {
                    Button("Open Item") {
                        selectedItem = "Nested"
                    }
                    .sheet(item: $selectedItem) { item in
                        Text(item)
                    }
                }
            }
            """
        )

        XCTAssertTrue(result.succeeded)

        guard case .navigationStack(let children) =
            result.document?.root,
        case .navigationLink(
            _,
            let destination
        ) = children.first,
        case .modified(
            _,
            let modifiers
        ) = destination,
        case .sheet = modifiers.first else {
            return XCTFail(
                "Expected item sheet inside navigation destination."
            )
        }
    }
}
