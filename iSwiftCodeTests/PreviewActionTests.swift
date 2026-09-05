import Foundation
import XCTest
@testable import iSwiftCode

final class PreviewActionTests: XCTestCase {
    func testValidatorAcceptsConstrainedProgram() throws {
        let definitions = [
            PreviewStateDefinition(
                name: "count",
                initialValue: .number(0)
            ),
            PreviewStateDefinition(
                name: "enabled",
                initialValue: .bool(false)
            ),
            PreviewStateDefinition(
                name: "title",
                initialValue: .string("Start")
            )
        ]

        let program = PreviewActionProgram(
            actions: [
                .add(
                    stateName: "count",
                    amount: 1
                ),
                .toggle(
                    stateName: "enabled"
                ),
                .set(
                    stateName: "title",
                    value: .string("Done")
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

    func testValidatorRejectsUnknownState() {
        let program = PreviewActionProgram(
            actions: [
                .toggle(
                    stateName: "missing"
                )
            ]
        )

        XCTAssertThrowsError(
            try PreviewActionValidator.validate(
                program,
                definitions: []
            )
        ) { error in
            XCTAssertEqual(
                error as? PreviewActionValidationError,
                .unknownState("missing")
            )
        }
    }

    func testValidatorRejectsTypeMismatch() {
        let program = PreviewActionProgram(
            actions: [
                .add(
                    stateName: "title",
                    amount: 1
                )
            ]
        )

        XCTAssertThrowsError(
            try PreviewActionValidator.validate(
                program,
                definitions: [
                    PreviewStateDefinition(
                        name: "title",
                        initialValue:
                            .string("Hello")
                    )
                ]
            )
        )
    }

    func testStateStorePerformsActionProgram() {
        let store = PreviewStateStore(
            definitions: [
                PreviewStateDefinition(
                    name: "count",
                    initialValue: .number(2)
                ),
                PreviewStateDefinition(
                    name: "enabled",
                    initialValue: .bool(false)
                ),
                PreviewStateDefinition(
                    name: "title",
                    initialValue: .string("Start")
                )
            ]
        )

        let performed = store.perform(
            PreviewActionProgram(
                actions: [
                    .add(
                        stateName: "count",
                        amount: 3
                    ),
                    .toggle(
                        stateName: "enabled"
                    ),
                    .set(
                        stateName: "title",
                        value: .string("Done")
                    )
                ]
            )
        )

        XCTAssertTrue(performed)
        XCTAssertEqual(
            store.value(for: "count"),
            .number(5)
        )
        XCTAssertEqual(
            store.value(for: "enabled"),
            .bool(true)
        )
        XCTAssertEqual(
            store.value(for: "title"),
            .string("Done")
        )
    }

    func testInvalidProgramDoesNotPartiallyMutateState() {
        let store = PreviewStateStore(
            definitions: [
                PreviewStateDefinition(
                    name: "count",
                    initialValue: .number(2)
                ),
                PreviewStateDefinition(
                    name: "title",
                    initialValue: .string("Start")
                )
            ]
        )

        let performed = store.perform(
            PreviewActionProgram(
                actions: [
                    .add(
                        stateName: "count",
                        amount: 3
                    ),
                    .toggle(
                        stateName: "title"
                    )
                ]
            )
        )

        XCTAssertFalse(performed)
        XCTAssertEqual(
            store.value(for: "count"),
            .number(2)
        )
        XCTAssertEqual(
            store.value(for: "title"),
            .string("Start")
        )
    }
}
