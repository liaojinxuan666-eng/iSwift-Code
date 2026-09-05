import Foundation
import XCTest
@testable import iSwiftCode

final class PreviewSheetTests: XCTestCase {
    private func preview(
        _ source: String
    ) throws -> PreviewProviderResult {
        try SwiftUISheetPreviewProvider()
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

    func testSheetLowersToPortableModifierIR() throws {
        let result = try preview(
            """
            @State private var showingDetails = false

            Button("Show") {
                showingDetails = true
            }
            .sheet(isPresented: $showingDetails) {
                Text("Details")
            }
            """
        )

        XCTAssertTrue(result.succeeded)

        guard case .modified(
            let base,
            let modifiers
        ) = result.document?.root,
        case .actionButton = base else {
            return XCTFail(
                "Expected actionable Button with sheet modifier."
            )
        }

        XCTAssertEqual(modifiers.count, 1)

        guard case .sheet(
            let reference,
            let content
        ) = modifiers[0] else {
            return XCTFail(
                "Expected portable sheet modifier."
            )
        }

        XCTAssertEqual(
            reference.stateName,
            "showingDetails"
        )
        XCTAssertEqual(
            content,
            .text("Details")
        )
    }

    func testSheetContentSharesPreviewStateAndCanDismiss() throws {
        let result = try preview(
            """
            @State private var showingDetails = false
            @State private var count = 0

            Button("Show") {
                showingDetails = true
            }
            .sheet(isPresented: $showingDetails) {
                VStack {
                    Text("Count: \\(count)")

                    Button("Add") {
                        count += 1
                    }

                    Button("Close") {
                        showingDetails = false
                    }
                }
            }
            """
        )

        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(
            result.document?
                .stateDefinitions
                .map(\.name),
            ["showingDetails", "count"]
        )

        guard case .modified(
            _,
            let modifiers
        ) = result.document?.root,
        case .sheet(
            _,
            let content
        ) = modifiers.first,
        case .vStack(let children) = content else {
            return XCTFail(
                "Expected state-aware sheet content."
            )
        }

        XCTAssertEqual(children.count, 3)
        guard case .actionButton = children[1],
              case .actionButton = children[2] else {
            return XCTFail(
                "Expected actionable sheet Buttons."
            )
        }
    }

    func testSheetInsideNavigationDestinationIsPreserved() throws {
        let result = try preview(
            """
            @State private var showingSheet = false

            NavigationStack {
                NavigationLink("Details") {
                    Button("Show Sheet") {
                        showingSheet = true
                    }
                    .sheet(isPresented: $showingSheet) {
                        Text("Presented")
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
                "Expected sheet inside navigation destination."
            )
        }
    }

    func testNestedSheetContentIsParsedRecursively() throws {
        let result = try preview(
            """
            @State private var showingFirst = false
            @State private var showingSecond = false

            Button("First") {
                showingFirst = true
            }
            .sheet(isPresented: $showingFirst) {
                Button("Second") {
                    showingSecond = true
                }
                .sheet(isPresented: $showingSecond) {
                    Text("Second sheet")
                }
            }
            """
        )

        XCTAssertTrue(result.succeeded)
        XCTAssertNotNil(result.document)
    }

    func testUnknownSheetStateProducesDiagnostic() throws {
        let result = try preview(
            """
            Text("Root")
                .sheet(isPresented: $missing) {
                    Text("Sheet")
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

    func testSheetRequiresBoolState() throws {
        let result = try preview(
            """
            @State private var mode = "sheet"

            Text("Root")
                .sheet(isPresented: $mode) {
                    Text("Sheet")
                }
            """
        )

        XCTAssertFalse(result.succeeded)
        XCTAssertNil(result.document)
        XCTAssertTrue(
            result.diagnostics.first?.message
                .contains("Bool") == true
        )
    }

    func testExistingNavigationAndControlsStillFallThrough() throws {
        let result = try preview(
            """
            @State private var enabled = true

            NavigationStack {
                NavigationLink("Details") {
                    Toggle("Enabled", isOn: $enabled)
                }
            }
            """
        )

        XCTAssertTrue(result.succeeded)
        XCTAssertNotNil(result.document)
    }
}
