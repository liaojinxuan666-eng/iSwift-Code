import Foundation
import XCTest
@testable import iSwiftCode

final class PreviewConditionalTests: XCTestCase {
    private func preview(
        _ source: String
    ) throws -> PreviewProviderResult {
        try SwiftUIConditionalPreviewProvider()
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

    func testBoolConditionalLowersInsideVStack() throws {
        let result = try preview(
            """
            @State private var showingDetails = false

            VStack {
                Button("Toggle") {
                    showingDetails.toggle()
                }

                if showingDetails {
                    Text("Details")
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut, value: showingDetails)
            """
        )

        XCTAssertTrue(result.succeeded)
        guard let root = result.document?.root else {
            return XCTFail("Missing preview root")
        }
        XCTAssertTrue(containsConditional(root))
        XCTAssertTrue(containsTransition(root))
    }

    func testNegatedConditionalWithElseLowers() throws {
        let result = try preview(
            """
            @State private var loading = true

            if !loading {
                Text("Ready")
            } else {
                Text("Loading")
            }
            """
        )

        XCTAssertTrue(result.succeeded)

        guard case .conditional(
            let condition,
            let whenTrue,
            let whenFalse
        ) = result.document?.root else {
            return XCTFail("Expected conditional root")
        }

        XCTAssertEqual(condition.stateName, "loading")
        XCTAssertTrue(condition.isNegated)
        XCTAssertEqual(whenTrue, [.text("Ready")])
        XCTAssertEqual(whenFalse, [.text("Loading")])
    }

    func testNestedBoolConditionalsLower() throws {
        let result = try preview(
            """
            @State private var outer = true
            @State private var inner = false

            if outer {
                Text("Outer")
                if inner {
                    Text("Inner")
                }
            }
            """
        )

        XCTAssertTrue(result.succeeded)
        guard let root = result.document?.root else {
            return XCTFail("Missing preview root")
        }
        XCTAssertGreaterThanOrEqual(
            conditionalCount(root),
            2
        )
    }

    func testUnknownConditionalStateProducesDiagnostic() throws {
        let result = try preview(
            """
            if missingState {
                Text("Missing")
            }
            """
        )

        XCTAssertFalse(result.succeeded)
        XCTAssertTrue(
            result.diagnostics.first?.message
                .contains("unknown @State") == true
        )
    }

    func testNonBoolConditionalStateProducesDiagnostic() throws {
        let result = try preview(
            """
            @State private var count = 1

            if count {
                Text("Wrong")
            }
            """
        )

        XCTAssertFalse(result.succeeded)
        XCTAssertTrue(
            result.diagnostics.first?.message
                .contains("Bool") == true
        )
    }

    func testIfInsideStringAndCommentIsIgnored() throws {
        let source =
            """
            Text("if showing { Text(\\\"Fake\\\") }")
            // if showing { Text("Comment") }
            """

        let rewrite = try PreviewConditionalSourceRewriter(
            source: source
        ).rewrite()

        XCTAssertTrue(rewrite.markers.isEmpty)
        XCTAssertEqual(rewrite.source, source)
    }

    private func containsConditional(
        _ node: PreviewNode
    ) -> Bool {
        switch node {
        case .conditional:
            return true
        case .vStack(let children),
             .hStack(let children),
             .zStack(let children),
             .scrollView(let children),
             .list(let children),
             .navigationStack(let children):
            return children.contains(where: containsConditional)
        case .navigationLink(_, let destination):
            return containsConditional(destination)
        case .modified(let base, _):
            return containsConditional(base)
        default:
            return false
        }
    }

    private func conditionalCount(
        _ node: PreviewNode
    ) -> Int {
        switch node {
        case .conditional(_, let whenTrue, let whenFalse):
            return 1 +
                whenTrue.reduce(0) { $0 + conditionalCount($1) } +
                whenFalse.reduce(0) { $0 + conditionalCount($1) }
        case .vStack(let children),
             .hStack(let children),
             .zStack(let children),
             .scrollView(let children),
             .list(let children),
             .navigationStack(let children):
            return children.reduce(0) { $0 + conditionalCount($1) }
        case .navigationLink(_, let destination):
            return conditionalCount(destination)
        case .modified(let base, _):
            return conditionalCount(base)
        default:
            return 0
        }
    }

    private func containsTransition(
        _ node: PreviewNode
    ) -> Bool {
        switch node {
        case .conditional(_, let whenTrue, let whenFalse):
            return (whenTrue + whenFalse)
                .contains(where: containsTransition)
        case .vStack(let children),
             .hStack(let children),
             .zStack(let children),
             .scrollView(let children),
             .list(let children),
             .navigationStack(let children):
            return children.contains(where: containsTransition)
        case .navigationLink(_, let destination):
            return containsTransition(destination)
        case .modified(let base, let modifiers):
            if modifiers.contains(where: {
                if case .transition = $0 {
                    return true
                }
                return false
            }) {
                return true
            }
            return containsTransition(base)
        default:
            return false
        }
    }
}
