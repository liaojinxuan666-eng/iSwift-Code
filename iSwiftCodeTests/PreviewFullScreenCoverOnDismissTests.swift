import Foundation
import XCTest
@testable import iSwiftCode

final class PreviewFullScreenCoverOnDismissTests: XCTestCase {
    private func preview(
        _ source: String
    ) throws -> PreviewProviderResult {
        try SwiftUIFullScreenCoverOnDismissPreviewProvider()
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

    func testFullScreenOnDismissLowersToConstrainedActionProgram() throws {
        let result = try preview(
            """
            @State private var showingCover = false
            @State private var status = "Open"

            Button("Show") {
                showingCover = true
            }
            .fullScreenCover(
                isPresented: $showingCover,
                onDismiss: {
                    status = "Closed"
                }
            ) {
                Text("Cover")
            }
            """
        )

        XCTAssertTrue(result.succeeded)

        guard case .modified(
            _,
            let modifiers
        ) = result.document?.root,
        case .fullScreenCoverWithOnDismiss(
            let reference,
            let program,
            let content
        ) = modifiers.first else {
            return XCTFail(
                "Expected fullScreenCoverWithOnDismiss modifier."
            )
        }

        XCTAssertEqual(
            reference.stateName,
            "showingCover"
        )
        XCTAssertEqual(
            program,
            PreviewActionProgram(
                actions: [
                    .set(
                        stateName: "status",
                        value: .string("Closed")
                    )
                ]
            )
        )
        XCTAssertEqual(
            content,
            .text("Cover")
        )
    }

    func testFullScreenOnDismissSupportsMultipleSafeMutations() throws {
        let result = try preview(
            """
            @State private var showingCover = false
            @State private var count = 0
            @State private var enabled = false

            Text("Root")
                .fullScreenCover(
                    isPresented: $showingCover,
                    onDismiss: {
                        count += 1
                        enabled.toggle()
                    }
                ) {
                    Text("Cover")
                }
            """
        )

        XCTAssertTrue(result.succeeded)

        guard case .modified(
            _,
            let modifiers
        ) = result.document?.root,
        case .fullScreenCoverWithOnDismiss(
            _,
            let program,
            _
        ) = modifiers.first else {
            return XCTFail(
                "Expected fullScreenCoverWithOnDismiss modifier."
            )
        }

        XCTAssertEqual(
            program.actions,
            [
                .add(
                    stateName: "count",
                    amount: 1
                ),
                .toggle(
                    stateName: "enabled"
                )
            ]
        )
    }

    func testUnknownFullScreenOnDismissStateProducesDiagnostic() throws {
        let result = try preview(
            """
            @State private var showingCover = false

            Text("Root")
                .fullScreenCover(
                    isPresented: $showingCover,
                    onDismiss: {
                        missing = "Closed"
                    }
                ) {
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

    func testIncompatibleFullScreenOnDismissMutationProducesDiagnostic() throws {
        let result = try preview(
            """
            @State private var showingCover = false
            @State private var title = "Cover"

            Text("Root")
                .fullScreenCover(
                    isPresented: $showingCover,
                    onDismiss: {
                        title += 1
                    }
                ) {
                    Text("Cover")
                }
            """
        )

        XCTAssertFalse(result.succeeded)
        XCTAssertNil(result.document)
        XCTAssertTrue(
            result.diagnostics.first?.message
                .contains("incompatible") == true
        )
    }

    func testUnsupportedFullScreenOnDismissSourceIsRejected() throws {
        let result = try preview(
            """
            @State private var showingCover = false

            Text("Root")
                .fullScreenCover(
                    isPresented: $showingCover,
                    onDismiss: {
                        print("closed")
                    }
                ) {
                    Text("Cover")
                }
            """
        )

        XCTAssertFalse(result.succeeded)
        XCTAssertNil(result.document)
        XCTAssertTrue(
            result.diagnostics.first?.message
                .contains("unsupported") == true
        )
    }

    func testLegacyFullScreenCoverStillUsesOriginalPortableCase() throws {
        let result = try preview(
            """
            @State private var showingCover = false

            Text("Root")
                .fullScreenCover(isPresented: $showingCover) {
                    Text("Cover")
                }
            """
        )

        XCTAssertTrue(result.succeeded)

        guard case .modified(
            _,
            let modifiers
        ) = result.document?.root,
        case .fullScreenCover = modifiers.first else {
            return XCTFail(
                "Expected original fullScreenCover modifier."
            )
        }
    }

    func testNestedFullScreenOnDismissCoversAreLoweredRecursively() throws {
        let result = try preview(
            """
            @State private var showingOuter = false
            @State private var showingInner = false
            @State private var count = 0

            Text("Root")
                .fullScreenCover(
                    isPresented: $showingOuter,
                    onDismiss: {
                        count += 1
                    }
                ) {
                    Text("Inner Host")
                        .fullScreenCover(
                            isPresented: $showingInner,
                            onDismiss: {
                                count += 2
                            }
                        ) {
                            Text("Inner")
                        }
                }
            """
        )

        XCTAssertTrue(result.succeeded)

        guard case .modified(
            _,
            let rootModifiers
        ) = result.document?.root,
        case .fullScreenCoverWithOnDismiss(
            _,
            _,
            let outerContent
        ) = rootModifiers.first,
        case .modified(
            _,
            let contentModifiers
        ) = outerContent,
        case .fullScreenCoverWithOnDismiss =
            contentModifiers.first else {
            return XCTFail(
                "Expected nested full-screen onDismiss modifiers."
            )
        }
    }
}
