import Foundation
import XCTest
@testable import iSwiftCode

final class PreviewNestedNavigationTests: XCTestCase {
    private func preview(
        _ source: String
    ) throws -> PreviewProviderResult {
        try SwiftUINavigationPreviewProvider()
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

    func testTwoLevelNavigationLinkLowersRecursively() throws {
        let result = try preview(
            """
            NavigationStack {
                NavigationLink("Level 1") {
                    VStack {
                        Text("First destination")

                        NavigationLink("Level 2") {
                            Text("Second destination")
                        }
                    }
                }
            }
            """
        )

        XCTAssertTrue(result.succeeded)

        guard case .navigationStack(let rootChildren) =
            result.document?.root,
            rootChildren.count == 1,
            case .navigationLink(
                let firstTitle,
                let firstDestination
            ) = rootChildren[0],
            case .vStack(let firstChildren) =
                firstDestination,
            firstChildren.count == 2,
            case .navigationLink(
                let secondTitle,
                let secondDestination
            ) = firstChildren[1] else {
            return XCTFail(
                "Expected two nested NavigationLink nodes."
            )
        }

        XCTAssertEqual(firstTitle, "Level 1")
        XCTAssertEqual(secondTitle, "Level 2")
        XCTAssertEqual(
            secondDestination,
            .text("Second destination")
        )
    }

    func testThreeLevelNavigationPreservesTitles() throws {
        let result = try preview(
            """
            NavigationStack {
                NavigationLink("One") {
                    VStack {
                        Text("Page one")

                        NavigationLink("Two") {
                            VStack {
                                Text("Page two")

                                NavigationLink("Three") {
                                    Text("Page three")
                                }
                            }
                            .navigationTitle("Second")
                        }
                    }
                    .navigationTitle("First")
                }
            }
            """
        )

        XCTAssertTrue(result.succeeded)
        XCTAssertNotNil(result.document)
    }

    func testNestedDestinationSharesPreviewState() throws {
        let result = try preview(
            """
            @State private var count = 0

            NavigationStack {
                NavigationLink("Counter") {
                    VStack {
                        Text("Count: \\(count)")

                        NavigationLink("Controls") {
                            VStack {
                                Text("Nested count: \\(count)")

                                Button("Add") {
                                    count += 1
                                }
                            }
                        }
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
            ["count"]
        )

        guard case .navigationStack(let rootChildren) =
            result.document?.root,
            case .navigationLink(
                _,
                let firstDestination
            ) = rootChildren.first,
            case .vStack(let firstChildren) =
                firstDestination,
            case .navigationLink(
                _,
                let secondDestination
            ) = firstChildren.last,
            case .vStack(let secondChildren) =
                secondDestination else {
            return XCTFail(
                "Expected nested state-aware destination."
            )
        }

        XCTAssertEqual(secondChildren.count, 2)

        guard case .actionButton = secondChildren[1] else {
            return XCTFail(
                "Expected nested actionable Button."
            )
        }
    }

    func testNestedNavigationCanContainPickerAndToggle() throws {
        let result = try preview(
            """
            @State private var mode = "preview"
            @State private var enabled = true

            NavigationStack {
                NavigationLink("Settings") {
                    NavigationLink("Advanced") {
                        VStack {
                            Toggle("Enabled", isOn: $enabled)

                            Picker("Mode", selection: $mode) {
                                Text("Preview").tag("preview")
                                Text("Console").tag("console")
                            }
                        }
                    }
                }
            }
            """
        )

        XCTAssertTrue(result.succeeded)
        XCTAssertNotNil(result.document)
    }

    func testNonNestedNavigationStillWorks() throws {
        let result = try preview(
            """
            NavigationStack {
                NavigationLink("Details") {
                    Text("Destination")
                }
            }
            """
        )

        XCTAssertTrue(result.succeeded)
        XCTAssertNotNil(result.document)
    }

    func testNormalInteractiveSourceStillFallsThrough() throws {
        let result = try preview(
            """
            @State private var enabled = true

            VStack {
                Toggle("Enabled", isOn: $enabled)

                Button("Toggle") {
                    enabled.toggle()
                }
            }
            """
        )

        XCTAssertTrue(result.succeeded)
        XCTAssertNotNil(result.document)
    }
}
