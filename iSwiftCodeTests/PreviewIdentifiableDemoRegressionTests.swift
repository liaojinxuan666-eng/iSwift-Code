import Foundation
import XCTest
@testable import iSwiftCode

final class PreviewIdentifiableDemoRegressionTests:
    XCTestCase {
    private let provider =
        SwiftUIIdentifiableItemValidationPreviewProvider()

    private func preview(
        source: String
    ) throws -> PreviewProviderResult {
        try provider.makePreview(
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

    func testBuiltInIdentifiableSheetDemoLowersEndToEnd() throws {
        let result = try preview(
            source:
                PreviewIdentifiableDemoCatalog
                    .sheetSource
        )

        XCTAssertTrue(result.succeeded)
        XCTAssertNotNil(result.document)
        XCTAssertTrue(result.diagnostics.isEmpty)

        let selectedItem =
            result.document?
                .stateDefinitions
                .first {
                    $0.name ==
                        "selectedItem"
                }

        XCTAssertNotNil(selectedItem)
    }

    func testBuiltInIdentifiableFullScreenDemoLowersEndToEnd() throws {
        let result = try preview(
            source:
                PreviewIdentifiableDemoCatalog
                    .fullScreenSource
        )

        XCTAssertTrue(result.succeeded)
        XCTAssertNotNil(result.document)
        XCTAssertTrue(result.diagnostics.isEmpty)

        let selectedProfile =
            result.document?
                .stateDefinitions
                .first {
                    $0.name ==
                        "selectedProfile"
                }

        XCTAssertNotNil(selectedProfile)
    }

    func testBuiltInDemosExerciseDirectAndInterpolatedMemberSyntax() {
        let sheet =
            PreviewIdentifiableDemoCatalog
                .sheetSource
        let fullScreen =
            PreviewIdentifiableDemoCatalog
                .fullScreenSource

        XCTAssertTrue(
            sheet.contains(
                "Text(item.title)"
            )
        )
        XCTAssertTrue(
            sheet.contains(
                #"Text("ID: \(item.id)")"#
            )
        )
        XCTAssertTrue(
            sheet.contains(
                #"Text("Subtitle: \(item.subtitle)")"#
            )
        )

        XCTAssertTrue(
            fullScreen.contains(
                "Text(item.name)"
            )
        )
        XCTAssertTrue(
            fullScreen.contains(
                #"Text("Enabled: \(item.enabled)")"#
            )
        )
    }

    func testBuiltInDemosExerciseConstructorActions() {
        let sheet =
            PreviewIdentifiableDemoCatalog
                .sheetSource
        let fullScreen =
            PreviewIdentifiableDemoCatalog
                .fullScreenSource

        XCTAssertTrue(
            sheet.contains(
                "selectedItem = DetailItem("
            )
        )
        XCTAssertTrue(
            fullScreen.contains(
                "selectedProfile = ProfileItem("
            )
        )
        XCTAssertTrue(
            sheet.contains(
                "selectedItem = nil"
            )
        )
        XCTAssertTrue(
            fullScreen.contains(
                "selectedProfile = nil"
            )
        )
    }

    func testBuiltInInvalidMemberDemoProducesDiagnostic() throws {
        let result = try preview(
            source:
                PreviewIdentifiableDemoCatalog
                    .invalidMemberSource
        )

        XCTAssertFalse(result.succeeded)
        XCTAssertNil(result.document)

        let message = try XCTUnwrap(
            result.diagnostics
                .first?
                .message
        )

        XCTAssertTrue(
            message.contains(
                "notExist"
            )
        )
        XCTAssertTrue(
            message.contains(
                "DetailItem"
            )
        )
    }
}
