import Foundation
import XCTest
@testable import iSwiftCode

final class PreviewIdentifiableItemStateBridgeTests: XCTestCase {
    private func item(
        typeName: String = "DetailItem",
        id: String = "details",
        title: String = "Details"
    ) -> PreviewIdentifiableItem {
        PreviewIdentifiableItem(
            typeName: typeName,
            id: .string(id),
            members: [
                PreviewItemMember(
                    name: "title",
                    value: .string(title)
                )
            ]
        )
    }

    private func optionalState(
        typeName: String = "DetailItem"
    ) -> PreviewStateValue {
        .optionalIdentifiableItem(
            PreviewOptionalIdentifiableItemState(
                itemTypeName: typeName
            )
        )
    }

    func testIdentifiableItemStateUsesStableIDDisplayText() {
        let value = PreviewStateValue.identifiableItem(
            item()
        )

        XCTAssertEqual(
            value.displayText,
            "details"
        )
        XCTAssertFalse(
            value.isNilOptional
        )
    }

    func testNilOptionalIdentifiableStateIsPreserved() {
        let value = optionalState()

        XCTAssertTrue(
            value.isNilOptional
        )
        XCTAssertEqual(
            value.displayText,
            ""
        )
    }

    func testActionValidatorAcceptsMatchingItemType() {
        let definitions = [
            PreviewStateDefinition(
                name: "selectedItem",
                initialValue: optionalState()
            )
        ]

        let program = PreviewActionProgram(
            actions: [
                .set(
                    stateName: "selectedItem",
                    value: .identifiableItem(
                        item()
                    )
                )
            ]
        )

        XCTAssertNoThrow(
            try PreviewActionValidator.validate(
                program,
                definitions: definitions
            )
        )
    }

    func testActionValidatorRejectsDifferentItemType() {
        let definitions = [
            PreviewStateDefinition(
                name: "selectedItem",
                initialValue: optionalState()
            )
        ]

        let program = PreviewActionProgram(
            actions: [
                .set(
                    stateName: "selectedItem",
                    value: .identifiableItem(
                        item(
                            typeName: "OtherItem"
                        )
                    )
                )
            ]
        )

        XCTAssertThrowsError(
            try PreviewActionValidator.validate(
                program,
                definitions: definitions
            )
        )
    }

    func testRuntimeStoreSetAndClearRoundTrip() {
        let model = item()
        let store = PreviewStateStore(
            definitions: [
                PreviewStateDefinition(
                    name: "selectedItem",
                    initialValue: optionalState()
                )
            ]
        )

        XCTAssertNil(
            store.optionalItemValue(
                for: "selectedItem"
            )
        )

        XCTAssertTrue(
            store.perform(
                PreviewActionProgram(
                    actions: [
                        .set(
                            stateName: "selectedItem",
                            value: .identifiableItem(
                                model
                            )
                        )
                    ]
                )
            )
        )

        XCTAssertEqual(
            store.optionalItemValue(
                for: "selectedItem"
            ),
            .identifiableItem(model)
        )
        XCTAssertEqual(
            store.value(
                for: "selectedItem"
            ),
            .optionalIdentifiableItem(
                PreviewOptionalIdentifiableItemState(
                    itemTypeName: "DetailItem",
                    item: model
                )
            )
        )

        XCTAssertTrue(
            store.perform(
                PreviewActionProgram(
                    actions: [
                        .clear(
                            stateName: "selectedItem"
                        )
                    ]
                )
            )
        )

        XCTAssertEqual(
            store.value(
                for: "selectedItem"
            ),
            optionalState()
        )
        XCTAssertNil(
            store.optionalItemValue(
                for: "selectedItem"
            )
        )
    }

    func testRuntimeStoreRejectsMismatchedItemTypeWithoutMutation() {
        let store = PreviewStateStore(
            definitions: [
                PreviewStateDefinition(
                    name: "selectedItem",
                    initialValue: optionalState()
                )
            ]
        )

        XCTAssertFalse(
            store.perform(
                PreviewActionProgram(
                    actions: [
                        .set(
                            stateName: "selectedItem",
                            value: .identifiableItem(
                                item(
                                    typeName: "OtherItem"
                                )
                            )
                        )
                    ]
                )
            )
        )

        XCTAssertEqual(
            store.value(
                for: "selectedItem"
            ),
            optionalState()
        )
    }

    func testPresentedOptionalItemKeepsTypeAndIdentity() {
        let model = item(
            id: "settings",
            title: "Settings"
        )
        let value = PreviewStateValue
            .optionalIdentifiableItem(
                PreviewOptionalIdentifiableItemState(
                    itemTypeName: "DetailItem",
                    item: model
                )
            )

        XCTAssertFalse(
            value.isNilOptional
        )
        XCTAssertEqual(
            value.displayText,
            "settings"
        )
    }
}
