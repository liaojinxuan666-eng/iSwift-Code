import Foundation
import XCTest
@testable import iSwiftCode

final class PreviewFullScreenCoverTests: XCTestCase {
    private func preview(
        _ source: String
    ) throws -> PreviewProviderResult {
        try SwiftUIFullScreenCoverPreviewProvider()
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

    func testFullScreenCoverLowersToPortableModifierIR() throws {
        let result = try preview(
            """
            @State private var showingCover = false

            Button("Open") {
                showingCover = true
            }
            .fullScreenCover(isPresented: $showingCover) {
                Text("Full Screen")
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
                "Expected actionable Button with fullScreenCover modifier."
            )
        }

        XCTAssertEqual(
            reference.stateName,
            "showingCover"
        )
        XCTAssertEqual(
            content,
            .text("Full Screen")
        )
    }

    func testFullScreenContentSharesStateAndCanClose() throws {
        let result = try preview(
            """
            @State private var showingCover = false
            @State private var count = 0

            Button("Open") {
                showingCover = true
            }
            .fullScreenCover(isPresented: $showingCover) {
                VStack {
                    Text("Count: \\(count)")

                    Button("Add") {
                        count += 1
                    }

                    Button("Close") {
                        showingCover = false
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
            ["showingCover", "count"]
        )

        guard case .modified(
            _,
            let modifiers
        ) = result.document?.root,
        case .fullScreenCover(
            _,
            let content
        ) = modifiers.first,
        case .vStack(let children) = content else {
            return XCTFail(
                "Expected state-aware full-screen content."
            )
        }

        XCTAssertEqual(children.count, 3)
        guard case .actionButton = children[1],
              case .actionButton = children[2] else {
            return XCTFail(
                "Expected actionable Buttons inside full-screen cover."
            )
        }
    }

    func testFullScreenCoverInsideNavigationDestination() throws {
        let result = try preview(
            """
            @State private var showingCover = false

            NavigationStack {
                NavigationLink("Details") {
                    Button("Open Full Screen") {
                        showingCover = true
                    }
                    .fullScreenCover(isPresented: $showingCover) {
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
            case .fullScreenCover = modifiers.first else {
            return XCTFail(
                "Expected full-screen cover inside navigation destination."
            )
        }
    }

    func testSheetInsideFullScreenCoverStillWorks() throws {
        let result = try preview(
            """
            @State private var showingCover = false
            @State private var showingSheet = false

            Text("Root")
                .fullScreenCover(isPresented: $showingCover) {
                    Button("Open Sheet") {
                        showingSheet = true
                    }
                    .sheet(isPresented: $showingSheet) {
                        Text("Sheet")
                    }
                }
            """
        )

        XCTAssertTrue(result.succeeded)
        XCTAssertNotNil(result.document)
    }

    func testFullScreenCoverInsideSheetIsResolved() throws {
        let result = try preview(
            """
            @State private var showingSheet = false
            @State private var showingCover = false

            Text("Root")
                .sheet(isPresented: $showingSheet) {
                    Button("Open Full Screen") {
                        showingCover = true
                    }
                    .fullScreenCover(isPresented: $showingCover) {
                        Text("Cover")
                    }
                }
            """
        )

        XCTAssertTrue(result.succeeded)

        guard case .modified(
            _,
            let rootModifiers
        ) = result.document?.root,
        case .sheet(
            _,
            let sheetContent
        ) = rootModifiers.first,
        case .modified(
            _,
            let contentModifiers
        ) = sheetContent,
        case .fullScreenCover = contentModifiers.first else {
            return XCTFail(
                "Expected full-screen cover inside sheet content."
            )
        }
    }

    func testNestedFullScreenCoversAreParsedRecursively() throws {
        let result = try preview(
            """
            @State private var showingFirst = false
            @State private var showingSecond = false

            Text("Root")
                .fullScreenCover(isPresented: $showingFirst) {
                    Button("Second") {
                        showingSecond = true
                    }
                    .fullScreenCover(isPresented: $showingSecond) {
                        Text("Second Cover")
                    }
                }
            """
        )

        XCTAssertTrue(result.succeeded)
        XCTAssertNotNil(result.document)
    }

    func testUnknownFullScreenStateProducesDiagnostic() throws {
        let result = try preview(
            """
            Text("Root")
                .fullScreenCover(isPresented: $missing) {
                    Text("Cover")
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

    func testFullScreenCoverRequiresBoolState() throws {
        let result = try preview(
            """
            @State private var mode = "cover"

            Text("Root")
                .fullScreenCover(isPresented: $mode) {
                    Text("Cover")
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

    func testExistingSheetAndNavigationStillFallThrough() throws {
        let result = try preview(
            """
            @State private var showingSheet = false

            NavigationStack {
                NavigationLink("Details") {
                    Text("Destination")
                }
            }
            .sheet(isPresented: $showingSheet) {
                Text("Sheet")
            }
            """
        )

        XCTAssertTrue(result.succeeded)
        XCTAssertNotNil(result.document)
    }
}
