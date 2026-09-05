import Foundation
import XCTest
@testable import iSwiftCode

final class PreviewFullScreenCoverItemTests: XCTestCase {
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

    func testOptionalStringFullScreenCoverItemLowersToPortableFullScreenCover() throws {
        let result = try preview(
            """
            @State private var selectedItem: String? = nil

            Button("Open") {
                selectedItem = "Details"
            }
            .fullScreenCover(item: $selectedItem) { item in
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
        case .fullScreenCover(
            let reference,
            let content
        ) = modifiers.first else {
            return XCTFail(
                "Expected action Button with item-driven portable full-screen cover."
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

    func testFullScreenCoverItemContentCanClearOptionalState() throws {
        let result = try preview(
            """
            @State private var selectedItem: String? = nil

            Button("Open") {
                selectedItem = "Details"
            }
            .fullScreenCover(item: $selectedItem) { item in
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
        case .fullScreenCover(
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
                "Expected constrained Close action inside item full-screen cover."
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

    func testFullScreenCoverItemInterpolationUsesOptionalStateValue() throws {
        let result = try preview(
            #"""
            @State private var selectedItem: String? = nil

            Text("Root")
                .fullScreenCover(item: $selectedItem) { item in
                    Text("Selected: \(item)")
                }
            """#
        )

        XCTAssertTrue(result.succeeded)

        guard case .modified(
            _,
            let modifiers
        ) = result.document?.root,
        case .fullScreenCover(
            _,
            let content
        ) = modifiers.first else {
            return XCTFail(
                "Expected item-driven full-screen cover modifier."
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
                .fullScreenCover(item: $selectedFlag) { item in
                    Text(item)
                }
            """
        )

        let numberResult = try preview(
            """
            @State private var selectedNumber: Int? = nil

            Text("Root")
                .fullScreenCover(item: $selectedNumber) { item in
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
                .fullScreenCover(item: $missing) { item in
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

    func testNonOptionalStateIsRejectedForFullScreenCoverItem() throws {
        let result = try preview(
            """
            @State private var selectedItem = "Details"

            Text("Root")
                .fullScreenCover(item: $selectedItem) { item in
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

    func testExistingBoolFullScreenCoverStillFallsThrough() throws {
        let result = try preview(
            """
            @State private var showingInfo = false

            Button("Open") {
                showingInfo = true
            }
            .fullScreenCover(isPresented: $showingInfo) {
                Text("Info")
            }
            """
        )

        XCTAssertTrue(result.succeeded)

        guard case .modified(
            _,
            let modifiers
        ) = result.document?.root,
        case .fullScreenCover(
            let reference,
            _
        ) = modifiers.first else {
            return XCTFail(
                "Expected existing Bool full-screen cover to remain supported."
            )
        }

        XCTAssertEqual(
            reference.stateName,
            "showingInfo"
        )
    }


    func testExistingSheetItemStillFallsThrough() throws {
        let result = try preview(
            """
            @State private var selectedItem: String? = nil

            Button("Open Sheet Item") {
                selectedItem = "Sheet"
            }
            .sheet(item: $selectedItem) { item in
                Text(item)
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
                "Expected existing sheet(item:) to remain supported."
            )
        }

        XCTAssertEqual(
            reference.stateName,
            "selectedItem"
        )
    }

    func testFullScreenCoverItemInsideNavigationDestination() throws {
        let result = try preview(
            """
            @State private var selectedItem: String? = nil

            NavigationStack {
                NavigationLink("Details") {
                    Button("Open Item") {
                        selectedItem = "Nested"
                    }
                    .fullScreenCover(item: $selectedItem) { item in
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
        case .fullScreenCover = modifiers.first else {
            return XCTFail(
                "Expected item full-screen cover inside navigation destination."
            )
        }
    }
}
