import Foundation
import XCTest
@testable import iSwiftCode

final class PreviewNavigationLabeledInitializerTests: XCTestCase {
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

    func testLabeledInitializerLowersToNavigationIR() throws {
        let result = try preview(
            """
            NavigationStack {
                NavigationLink(
                    destination: {
                        Text("Details")
                    },
                    label: {
                        Text("Open")
                    }
                )
            }
            """
        )

        XCTAssertTrue(result.succeeded)

        guard case .navigationStack(let children) =
            result.document?.root,
            children.count == 1 else {
            return XCTFail(
                "Expected NavigationStack root."
            )
        }

        XCTAssertEqual(
            children[0],
            .navigationLink(
                title: "Open",
                destination: .text("Details")
            )
        )
    }

    func testLabeledInitializerDestinationCanUseState() throws {
        let result = try preview(
            """
            @State private var count = 0

            NavigationStack {
                NavigationLink(
                    destination: {
                        VStack {
                            Text("Count: \\(count)")

                            Button("Add") {
                                count += 1
                            }
                        }
                    },
                    label: {
                        Text("Counter")
                    }
                )
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
    }

    func testLabeledInitializerCanNestNavigationLink() throws {
        let result = try preview(
            """
            NavigationStack {
                NavigationLink(
                    destination: {
                        VStack {
                            Text("First")

                            NavigationLink("Second") {
                                Text("Second page")
                            }
                        }
                    },
                    label: {
                        Text("First page")
                    }
                )
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
            case .vStack(let destinationChildren) =
                destination,
            case .navigationLink =
                destinationChildren.last else {
            return XCTFail(
                "Expected nested NavigationLink."
            )
        }
    }

    func testLabeledInitializerKeepsOuterModifiers() throws {
        let result = try preview(
            """
            NavigationStack {
                NavigationLink(
                    destination: {
                        Text("Details")
                    },
                    label: {
                        Text("Open")
                    }
                )
                .padding(8)
            }
            """
        )

        XCTAssertTrue(result.succeeded)

        guard case .navigationStack(let children) =
            result.document?.root,
            case .modified(
                let base,
                let modifiers
            ) = children.first,
            case .navigationLink = base else {
            return XCTFail(
                "Expected modified NavigationLink."
            )
        }

        let expected: [PreviewModifier] = [
            .padding(8)
        ]
        XCTAssertEqual(
            modifiers,
            expected
        )
    }

    func testNonLiteralLabelIsRejectedForNow() throws {
        let result = try preview(
            """
            NavigationStack {
                NavigationLink(
                    destination: {
                        Text("Details")
                    },
                    label: {
                        Image(systemName: "arrow.right")
                    }
                )
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

    func testExistingTrailingClosureFormStillWorks() throws {
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
}
