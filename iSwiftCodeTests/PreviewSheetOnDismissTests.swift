import Foundation
import XCTest
@testable import iSwiftCode

final class PreviewSheetOnDismissTests: XCTestCase {
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

    func testSheetOnDismissLowersToConstrainedActionProgram() throws {
        let result = try preview(
            """
            @State private var showingInfo = false
            @State private var status = "Open"

            Button("Show") {
                showingInfo = true
            }
            .sheet(
                isPresented: $showingInfo,
                onDismiss: {
                    status = "Closed"
                }
            ) {
                Text("Info")
            }
            """
        )

        XCTAssertTrue(result.succeeded)

        guard case .modified(
            _,
            let modifiers
        ) = result.document?.root,
        case .sheetWithOnDismiss(
            let reference,
            let program,
            let content
        ) = modifiers.first else {
            return XCTFail(
                "Expected sheetWithOnDismiss modifier."
            )
        }

        XCTAssertEqual(
            reference.stateName,
            "showingInfo"
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
            .text("Info")
        )
    }

    func testOnDismissSupportsMultipleSafeMutations() throws {
        let result = try preview(
            """
            @State private var showingInfo = false
            @State private var count = 0
            @State private var enabled = false

            Text("Root")
                .sheet(
                    isPresented: $showingInfo,
                    onDismiss: {
                        count += 1
                        enabled.toggle()
                    }
                ) {
                    Text("Info")
                }
            """
        )

        XCTAssertTrue(result.succeeded)

        guard case .modified(
            _,
            let modifiers
        ) = result.document?.root,
        case .sheetWithOnDismiss(
            _,
            let program,
            _
        ) = modifiers.first else {
            return XCTFail(
                "Expected sheetWithOnDismiss modifier."
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

    func testOnDismissCanSetBoolAndNumberState() throws {
        let result = try preview(
            """
            @State private var showingInfo = false
            @State private var enabled = true
            @State private var count = 7

            Text("Root")
                .sheet(
                    isPresented: $showingInfo,
                    onDismiss: {
                        enabled = false
                        count = 10
                    }
                ) {
                    Text("Info")
                }
            """
        )

        XCTAssertTrue(result.succeeded)
        XCTAssertNotNil(result.document)
    }

    func testUnknownOnDismissStateProducesDiagnostic() throws {
        let result = try preview(
            """
            @State private var showingInfo = false

            Text("Root")
                .sheet(
                    isPresented: $showingInfo,
                    onDismiss: {
                        missing = "Closed"
                    }
                ) {
                    Text("Info")
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

    func testIncompatibleOnDismissMutationProducesDiagnostic() throws {
        let result = try preview(
            """
            @State private var showingInfo = false
            @State private var title = "Info"

            Text("Root")
                .sheet(
                    isPresented: $showingInfo,
                    onDismiss: {
                        title += 1
                    }
                ) {
                    Text("Info")
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

    func testUnsupportedOnDismissSourceIsRejected() throws {
        let result = try preview(
            """
            @State private var showingInfo = false

            Text("Root")
                .sheet(
                    isPresented: $showingInfo,
                    onDismiss: {
                        print("closed")
                    }
                ) {
                    Text("Info")
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

    func testLegacySheetStillUsesOriginalPortableCase() throws {
        let result = try preview(
            """
            @State private var showingInfo = false

            Text("Root")
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
        case .sheet = modifiers.first else {
            return XCTFail(
                "Expected original sheet modifier."
            )
        }
    }
}
