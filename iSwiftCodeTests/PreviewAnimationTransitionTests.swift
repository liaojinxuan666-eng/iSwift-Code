import Foundation
import XCTest
@testable import iSwiftCode

final class PreviewAnimationTransitionTests:
    XCTestCase {
    private func preview(
        _ source: String
    ) throws -> PreviewProviderResult {
        try SwiftUIAnimationTransitionPreviewProvider()
            .makePreview(
                PreviewRequest(
                    files: [
                        PreviewSourceFile(
                            path:
                                "ContentView.swift",
                            contents:
                                source
                        )
                    ],
                    entryFilePath:
                        "ContentView.swift"
                )
            )
    }

    func testValueDrivenAnimationAndOpacityTransitionLower() throws {
        let result = try preview(
            """
            @State private var count = 0

            VStack {
                Text("Count")
            }
            .animation(
                .easeInOut(duration: 0.25),
                value: count
            )
            .transition(.opacity)
            """
        )

        XCTAssertTrue(result.succeeded)

        let modifiers =
            try XCTUnwrap(
                rootModifiers(
                    result.document?.root
                )
            )

        XCTAssertTrue(
            modifiers.contains(
                .animation(
                    PreviewAnimationSpec(
                        curve:
                            .easeInOut,
                        duration:
                            0.25
                    ),
                    value:
                        PreviewBindingReference(
                            stateName:
                                "count"
                        )
                )
            )
        )

        XCTAssertTrue(
            modifiers.contains(
                .transition(
                    .opacity
                )
            )
        )
    }

    func testSpringAndMoveTransitionLower() throws {
        let result = try preview(
            """
            @State private var enabled = false

            Text("Motion")
                .animation(
                    .spring(),
                    value: enabled
                )
                .transition(
                    .move(edge: .leading)
                )
            """
        )

        XCTAssertTrue(result.succeeded)

        let modifiers =
            try XCTUnwrap(
                rootModifiers(
                    result.document?.root
                )
            )

        XCTAssertTrue(
            modifiers.contains(
                .animation(
                    PreviewAnimationSpec(
                        curve:
                            .spring
                    ),
                    value:
                        PreviewBindingReference(
                            stateName:
                                "enabled"
                        )
                )
            )
        )

        XCTAssertTrue(
            modifiers.contains(
                .transition(
                    .move(
                        .leading
                    )
                )
            )
        )
    }

    func testUnknownAnimationStateProducesDiagnostic() throws {
        let result = try preview(
            """
            @State private var count = 0

            Text("Motion")
                .animation(
                    .linear,
                    value: missing
                )
            """
        )

        XCTAssertFalse(result.succeeded)
        XCTAssertNil(result.document)

        XCTAssertTrue(
            result.diagnostics
                .first?
                .message
                .contains(
                    "missing"
                ) == true
        )
    }

    func testMotionSyntaxInsideStringAndCommentIsIgnored() throws {
        let source =
            """
            @State private var count = 0

            VStack {
                Text(".transition(.opacity)")
                // .animation(.easeInOut, value: count)
                Text("Ready")
            }
            """

        let rewrite =
            try PreviewMotionSourceRewriter(
                source: source
            ).rewrite()

        XCTAssertTrue(
            rewrite.markers.isEmpty
        )
        XCTAssertEqual(
            rewrite.source,
            source
        )
    }

    func testSimpleTransitionKindsRewrite() throws {
        let source =
            """
            @State private var count = 0

            VStack {
                Text("A")
                    .transition(.scale)

                Text("B")
                    .transition(.slide)

                Text("C")
                    .animation(.default, value: count)
            }
            """

        let rewrite =
            try PreviewMotionSourceRewriter(
                source: source
            ).rewrite()

        XCTAssertEqual(
            rewrite.markers.count,
            3
        )
        XCTAssertFalse(
            rewrite.source.contains(
                ".transition(.scale)"
            )
        )
        XCTAssertFalse(
            rewrite.source.contains(
                ".transition(.slide)"
            )
        )
        XCTAssertFalse(
            rewrite.source.contains(
                ".animation(.default, value: count)"
            )
        )
    }

    private func rootModifiers(
        _ node: PreviewNode?
    ) -> [PreviewModifier]? {
        guard let node else {
            return nil
        }

        if case .modified(
            _,
            let modifiers
        ) = node {
            return modifiers
        }

        return nil
    }
}
