import Foundation
import XCTest
@testable import iSwiftCode

final class PreviewIdentifiableMemberValidationTests:
    XCTestCase {
    private func preview(
        _ source: String
    ) throws -> PreviewProviderResult {
        try SwiftUIIdentifiableItemValidationPreviewProvider()
            .makePreview(
                PreviewRequest(
                    files: [
                        PreviewSourceFile(
                            path:
                                "ContentView.swift",
                            contents: source
                        )
                    ],
                    entryFilePath:
                        "ContentView.swift"
                )
            )
    }

    func testUnknownDirectMemberProducesDiagnostic() throws {
        let result = try preview(
            """
            struct DetailItem: Identifiable {
                let id: Int
                let title: String
            }

            @State private var selectedItem: DetailItem? = nil

            VStack {
                Text("Ready")
            }
            .sheet(item: $selectedItem) { item in
                Text(item.notExist)
            }
            """
        )

        XCTAssertFalse(result.succeeded)
        XCTAssertNil(result.document)

        let message = try XCTUnwrap(
            result.diagnostics.first?.message
        )

        XCTAssertTrue(
            message.contains(
                "DetailItem"
            )
        )
        XCTAssertTrue(
            message.contains(
                "notExist"
            )
        )
        XCTAssertTrue(
            message.contains(
                "id"
            )
        )
        XCTAssertTrue(
            message.contains(
                "title"
            )
        )
    }

    func testUnknownInterpolatedMemberProducesDiagnostic() throws {
        let result = try preview(
            """
            struct DetailItem: Identifiable {
                let id: Int
                let title: String
            }

            @State private var selectedItem: DetailItem? = nil

            VStack {
                Text("Ready")
            }
            .fullScreenCover(item: $selectedItem) { item in
                Text("Missing: \\(item.notExist)")
            }
            """
        )

        XCTAssertFalse(result.succeeded)
        XCTAssertTrue(
            result.diagnostics
                .first?
                .message
                .contains(
                    "notExist"
                ) == true
        )
    }

    func testKnownDirectAndInterpolatedMembersStillPass() throws {
        let result = try preview(
            """
            struct DetailItem: Identifiable {
                let id: Int
                let title: String
            }

            @State private var selectedItem: DetailItem? = nil

            VStack {
                Button("Open") {
                    selectedItem = DetailItem(
                        id: 1,
                        title: "Details"
                    )
                }
            }
            .sheet(item: $selectedItem) { item in
                Text(item.title)
                Text("ID: \\(item.id)")
            }
            """
        )

        XCTAssertTrue(result.succeeded)
        XCTAssertNotNil(result.document)
    }

    func testPrimitiveItemStateRemainsOnExistingPath() throws {
        let result = try preview(
            """
            @State private var selectedItem: String? = nil

            VStack {
                Text("Ready")
            }
            .sheet(item: $selectedItem) { item in
                Text(item)
            }
            """
        )

        XCTAssertTrue(result.succeeded)
    }

    func testCommentedUnknownMemberDoesNotProduceValidationIssue() throws {
        let source =
            """
            struct DetailItem: Identifiable {
                let id: Int
                let title: String
            }

            @State private var selectedItem: DetailItem? = nil

            VStack {
                Text("Ready")
            }
            .sheet(item: $selectedItem) { item in
                // Text(item.notExist)
                Text(item.title)
            }
            """

        let issues =
            try PreviewIdentifiableMemberSourceValidator(
                source: source
            ).validate()

        XCTAssertTrue(issues.isEmpty)
    }

    func testValidatorReportsDistinctUnknownMembers() throws {
        let source =
            """
            struct DetailItem: Identifiable {
                let id: Int
                let title: String
            }

            @State private var selectedItem: DetailItem? = nil

            VStack {
                Text("Ready")
            }
            .sheet(item: $selectedItem) { item in
                Text(item.firstMissing)
                Text("Other: \\(item.secondMissing)")
            }
            """

        let issues =
            try PreviewIdentifiableMemberSourceValidator(
                source: source
            ).validate()

        XCTAssertEqual(
            Set(
                issues.map {
                    $0.memberName
                }
            ),
            Set([
                "firstMissing",
                "secondMissing"
            ])
        )
    }
}
