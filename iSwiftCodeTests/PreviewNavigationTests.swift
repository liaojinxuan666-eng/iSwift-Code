import Foundation
import XCTest
@testable import iSwiftCode

final class PreviewNavigationTests: XCTestCase {
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

    func testSimpleNavigationLinkLowersToPortableIR() throws {
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

        guard case .navigationStack(let children) =
            result.document?.root,
            children.count == 1 else {
            return XCTFail("Expected NavigationStack root.")
        }

        XCTAssertEqual(
            children[0],
            .navigationLink(
                title: "Details",
                destination: .text("Destination")
            )
        )
    }

    func testNavigationLinkKeepsOuterModifiers() throws {
        let result = try preview(
            """
            NavigationStack {
                NavigationLink("Details") {
                    Text("Destination")
                }
                .padding(8)
            }
            """
        )

        XCTAssertTrue(result.succeeded)

        guard case .navigationStack(let children) =
            result.document?.root,
            children.count == 1,
            case .modified(let base, let modifiers) = children[0],
            case .navigationLink = base else {
            return XCTFail("Expected modified NavigationLink.")
        }

        let expected: [PreviewModifier] = [.padding(8)]
        XCTAssertEqual(modifiers, expected)
    }

    func testDestinationCanReadSharedPreviewState() throws {
        let result = try preview(
            """
            @State private var name = "Guest"

            NavigationStack {
                NavigationLink("Profile") {
                    Text("Hello, \\(name)")
                }
            }
            """
        )

        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(
            result.document?.stateDefinitions.map(\.name),
            ["name"]
        )
    }

    func testDestinationCanContainSafeActionButton() throws {
        let result = try preview(
            """
            @State private var count = 0

            NavigationStack {
                NavigationLink("Counter") {
                    VStack {
                        Text("Count: \\(count)")
                        Button("Add") {
                            count += 1
                        }
                    }
                }
            }
            """
        )

        XCTAssertTrue(result.succeeded)

        guard case .navigationStack(let children) =
            result.document?.root,
            children.count == 1,
            case .navigationLink(_, let destination) = children[0] else {
            return XCTFail("Expected NavigationLink.")
        }

        guard case .vStack(let destinationChildren) = destination else {
            return XCTFail("Expected VStack destination.")
        }

        XCTAssertEqual(destinationChildren.count, 2)
        guard case .actionButton = destinationChildren[1] else {
            return XCTFail("Expected actionable Button in destination.")
        }
    }

    func testMultipleTopLevelDestinationViewsArePreserved() throws {
        let result = try preview(
            """
            NavigationStack {
                NavigationLink("Details") {
                    Text("One")
                    Text("Two")
                }
            }
            """
        )

        XCTAssertTrue(result.succeeded)

        guard case .navigationStack(let children) =
            result.document?.root,
            children.count == 1,
            case .navigationLink(_, let destination) = children[0],
            case .vStack(let destinationChildren) = destination else {
            return XCTFail("Expected multi-view destination wrapper.")
        }

        XCTAssertEqual(
            destinationChildren,
            [.text("One"), .text("Two")]
        )
    }

    func testExistingInteractivePreviewStillFallsThrough() throws {
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
