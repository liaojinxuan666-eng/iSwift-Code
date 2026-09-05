import Foundation
import XCTest
@testable import iSwiftCode

final class PreviewIdentifiableModelSourceTests:
    XCTestCase {
    private func preview(
        _ source: String
    ) throws -> PreviewProviderResult {
        try SwiftUIIdentifiableModelPreviewProvider()
            .makePreview(
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

    func testParsesTypedOptionalIdentifiableState() throws {
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
            """
        )

        XCTAssertTrue(result.succeeded)

        let definition = try XCTUnwrap(
            result.document?
                .stateDefinitions
                .first(
                    where: {
                        $0.name ==
                            "selectedItem"
                    }
                )
        )

        XCTAssertEqual(
            definition.initialValue,
            .optionalIdentifiableItem(
                PreviewOptionalIdentifiableItemState(
                    itemTypeName:
                        "DetailItem"
                )
            )
        )
    }

    func testSupportsIdentifiableAmongMultipleConformances() throws {
        let result = try preview(
            """
            struct DetailItem: Equatable, Identifiable {
                let id: String
                let title: String
                let enabled: Bool
                let count: Int
            }

            @State private var selectedItem: DetailItem? = nil

            VStack {
                Text("Ready")
            }
            """
        )

        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(
            result.document?
                .stateDefinitions
                .first(
                    where: {
                        $0.name ==
                            "selectedItem"
                    }
                )?
                .initialValue,
            .optionalIdentifiableItem(
                PreviewOptionalIdentifiableItemState(
                    itemTypeName:
                        "DetailItem"
                )
            )
        )
    }

    func testPrimitiveOptionalStateStillUsesExistingPath() throws {
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
        XCTAssertEqual(
            result.document?
                .stateDefinitions
                .first?
                .initialValue,
            .optionalString(nil)
        )
    }

    func testCustomModelItemSheetCanBeStructurallyLowered() throws {
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
                Text(item)
            }
            """
        )

        XCTAssertTrue(result.succeeded)

        guard case .modified(
            _,
            let modifiers
        ) = result.document?.root else {
            return XCTFail(
                "Expected item sheet modifier."
            )
        }

        XCTAssertTrue(
            modifiers.contains(
                where: { modifier in
                    guard case .sheet(
                        let reference,
                        _
                    ) = modifier else {
                        return false
                    }

                    return reference.stateName ==
                        "selectedItem"
                }
            )
        )

        XCTAssertEqual(
            result.document?
                .stateDefinitions
                .first(
                    where: {
                        $0.name ==
                            "selectedItem"
                    }
                )?
                .initialValue,
            .optionalIdentifiableItem(
                PreviewOptionalIdentifiableItemState(
                    itemTypeName:
                        "DetailItem"
                )
            )
        )
    }

    func testCustomModelFullScreenItemCanBeStructurallyLowered() throws {
        let result = try preview(
            """
            struct DetailItem: Identifiable {
                let id: String
                let title: String
            }

            @State private var selectedItem: DetailItem? = nil

            VStack {
                Text("Ready")
            }
            .fullScreenCover(item: $selectedItem) { item in
                Text(item)
            }
            """
        )

        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(
            result.document?
                .stateDefinitions
                .first(
                    where: {
                        $0.name ==
                            "selectedItem"
                    }
                )?
                .initialValue,
            .optionalIdentifiableItem(
                PreviewOptionalIdentifiableItemState(
                    itemTypeName:
                        "DetailItem"
                )
            )
        )
    }

    func testModelWithoutIDProducesDiagnostic() throws {
        let result = try preview(
            """
            struct DetailItem: Identifiable {
                let title: String
            }

            @State private var selectedItem: DetailItem? = nil

            VStack {
                Text("Ready")
            }
            """
        )

        XCTAssertFalse(result.succeeded)
        XCTAssertNil(result.document)
        XCTAssertTrue(
            result.diagnostics
                .first?
                .message
                .contains("id") == true
        )
    }

    func testUnsupportedMemberTypeProducesDiagnostic() throws {
        let result = try preview(
            """
            struct DetailItem: Identifiable {
                let id: Int
                let date: Date
            }

            @State private var selectedItem: DetailItem? = nil

            VStack {
                Text("Ready")
            }
            """
        )

        XCTAssertFalse(result.succeeded)
        XCTAssertNil(result.document)
        XCTAssertTrue(
            result.diagnostics
                .first?
                .message
                .contains("Date") == true
        )
    }
}
