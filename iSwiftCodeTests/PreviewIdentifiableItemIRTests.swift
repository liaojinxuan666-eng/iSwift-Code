import Foundation
import XCTest
@testable import iSwiftCode

final class PreviewIdentifiableItemIRTests: XCTestCase {
    private func makeItem() -> PreviewIdentifiableItem {
        PreviewIdentifiableItem(
            typeName: "PreviewCard",
            id: .string("details"),
            members: [
                PreviewItemMember(
                    name: "title",
                    value: .string("Details")
                ),
                PreviewItemMember(
                    name: "count",
                    value: .number(3)
                ),
                PreviewItemMember(
                    name: "enabled",
                    value: .bool(true)
                )
            ]
        )
    }

    func testIdentifiableItemPreservesPortableModelData() {
        let item = makeItem()

        XCTAssertEqual(
            item.typeName,
            "PreviewCard"
        )
        XCTAssertEqual(
            item.id,
            .string("details")
        )
        XCTAssertEqual(
            item.member(named: "title"),
            .string("Details")
        )
        XCTAssertEqual(
            item.member(named: "count"),
            .number(3)
        )
        XCTAssertEqual(
            item.member(named: "enabled"),
            .bool(true)
        )
    }

    func testIdentifiableIDIsAvailableAsMember() {
        let item = makeItem()

        XCTAssertEqual(
            item.member(named: "id"),
            .string("details")
        )
        XCTAssertEqual(
            item.displayText(forMember: "id"),
            "details"
        )
    }

    func testUnknownMemberDoesNotExecuteFallbackCode() {
        let item = makeItem()

        XCTAssertNil(
            item.member(named: "missing")
        )
    }

    func testOptionalItemStateTracksPresentationPortably() {
        let item = makeItem()
        let empty = PreviewOptionalIdentifiableItemState(
            itemTypeName: "PreviewCard"
        )

        XCTAssertFalse(empty.isPresented)
        XCTAssertNil(empty.item)

        let presented = empty.presenting(item)

        XCTAssertTrue(presented.isPresented)
        XCTAssertEqual(
            presented.item,
            item
        )

        let cleared = presented.clearing()

        XCTAssertFalse(cleared.isPresented)
        XCTAssertNil(cleared.item)
        XCTAssertEqual(
            cleared.itemTypeName,
            "PreviewCard"
        )
    }

    func testMemberValuesAreHashableAndDisplayDeterministically() {
        let values: Set<PreviewItemMemberValue> = [
            .string("Details"),
            .bool(true),
            .number(3)
        ]

        XCTAssertEqual(values.count, 3)
        XCTAssertEqual(
            PreviewItemMemberValue.number(3)
                .displayText,
            "3"
        )
        XCTAssertEqual(
            PreviewItemMemberValue.number(3.5)
                .displayText,
            "3.5"
        )
    }
}
