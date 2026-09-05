import Foundation
import XCTest
@testable import iSwiftCode

final class PreviewIdentifiableModelActionTests: XCTestCase {
    private func preview(
        _ source: String
    ) throws -> PreviewProviderResult {
        try SwiftUIIdentifiableModelActionPreviewProvider()
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

    func testConstructorAssignmentLowersToPortableItemAction() throws {
        let result = try preview(
            """
            struct DetailItem: Identifiable {
                let id: Int
                let title: String
                let enabled: Bool
                let score: Double
            }

            @State private var selectedItem: DetailItem? = nil

            VStack {
                Button("Open") {
                    selectedItem = DetailItem(
                        id: 7,
                        title: "Details",
                        enabled: true,
                        score: 2.5
                    )
                }
            }
            .sheet(item: $selectedItem) { item in
                Text(item)
            }
            """
        )

        XCTAssertTrue(result.succeeded)

        let program = try XCTUnwrap(
            firstActionProgram(
                in: try XCTUnwrap(
                    result.document?.root
                )
            )
        )

        XCTAssertEqual(
            program,
            PreviewActionProgram(
                actions: [
                    .set(
                        stateName: "selectedItem",
                        value: .identifiableItem(
                            PreviewIdentifiableItem(
                                typeName: "DetailItem",
                                id: .number(7),
                                members: [
                                    PreviewItemMember(
                                        name: "title",
                                        value: .string("Details")
                                    ),
                                    PreviewItemMember(
                                        name: "enabled",
                                        value: .bool(true)
                                    ),
                                    PreviewItemMember(
                                        name: "score",
                                        value: .number(2.5)
                                    )
                                ]
                            )
                        )
                    )
                ]
            )
        )
    }

    func testConstructorAssignmentWorksWithFullScreenItem() throws {
        let result = try preview(
            """
            struct DetailItem: Identifiable {
                let id: String
                let title: String
            }

            @State private var selectedItem: DetailItem? = nil

            VStack {
                Button("Open") {
                    selectedItem = DetailItem(
                        id: "settings",
                        title: "Settings"
                    )
                }
            }
            .fullScreenCover(item: $selectedItem) { item in
                Text(item)
            }
            """
        )

        XCTAssertTrue(result.succeeded)

        let program = try XCTUnwrap(
            firstActionProgram(
                in: try XCTUnwrap(
                    result.document?.root
                )
            )
        )

        XCTAssertEqual(
            program.actions.first,
            .set(
                stateName: "selectedItem",
                value: .identifiableItem(
                    PreviewIdentifiableItem(
                        typeName: "DetailItem",
                        id: .string("settings"),
                        members: [
                            PreviewItemMember(
                                name: "title",
                                value: .string("Settings")
                            )
                        ]
                    )
                )
            )
        )
    }

    func testConstructorCanBeClearedByExistingOptionalAction() throws {
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

                Button("Clear") {
                    selectedItem = nil
                }
            }
            """
        )

        XCTAssertTrue(result.succeeded)

        let programs = actionPrograms(
            in: try XCTUnwrap(
                result.document?.root
            )
        )

        XCTAssertEqual(programs.count, 2)
        XCTAssertEqual(
            programs.last,
            PreviewActionProgram(
                actions: [
                    .clear(
                        stateName: "selectedItem"
                    )
                ]
            )
        )
    }

    func testConstructorRejectsWrongModelType() throws {
        let result = try preview(
            """
            struct DetailItem: Identifiable {
                let id: Int
            }

            struct OtherItem: Identifiable {
                let id: Int
            }

            @State private var selectedItem: DetailItem? = nil

            VStack {
                Button("Open") {
                    selectedItem = OtherItem(id: 1)
                }
            }
            """
        )

        XCTAssertFalse(result.succeeded)
        XCTAssertNil(result.document)
        XCTAssertTrue(
            result.diagnostics.first?.message
                .contains("OtherItem") == true
        )
    }

    func testConstructorRejectsMissingMember() throws {
        let result = try preview(
            """
            struct DetailItem: Identifiable {
                let id: Int
                let title: String
            }

            @State private var selectedItem: DetailItem? = nil

            VStack {
                Button("Open") {
                    selectedItem = DetailItem(id: 1)
                }
            }
            """
        )

        XCTAssertFalse(result.succeeded)
        XCTAssertNil(result.document)
        XCTAssertTrue(
            result.diagnostics.first?.message
                .contains("title") == true
        )
    }

    func testConstructorRejectsWrongLiteralType() throws {
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
                        title: 123
                    )
                }
            }
            """
        )

        XCTAssertFalse(result.succeeded)
        XCTAssertNil(result.document)
        XCTAssertTrue(
            result.diagnostics.first?.message
                .contains("String") == true
        )
    }

    func testPrimitiveButtonAssignmentsRemainOnExistingPath() throws {
        let result = try preview(
            """
            @State private var title = "Ready"

            VStack {
                Button("Change") {
                    title = "Done"
                }
                Text(title)
            }
            """
        )

        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(
            firstActionProgram(
                in: try XCTUnwrap(
                    result.document?.root
                )
            ),
            PreviewActionProgram(
                actions: [
                    .set(
                        stateName: "title",
                        value: .string("Done")
                    )
                ]
            )
        )
    }

    private func firstActionProgram(
        in node: PreviewNode
    ) -> PreviewActionProgram? {
        actionPrograms(in: node).first
    }

    private func actionPrograms(
        in node: PreviewNode
    ) -> [PreviewActionProgram] {
        switch node {
        case .actionButton(_, let program):
            return [program]

        case .vStack(let children),
             .hStack(let children),
             .zStack(let children),
             .scrollView(let children),
             .list(let children),
             .navigationStack(let children):
            return children.flatMap(
                actionPrograms(in:)
            )

        case .navigationLink(_, let destination):
            return actionPrograms(
                in: destination
            )

        case .modified(let base, let modifiers):
            return actionPrograms(in: base) +
                modifiers.flatMap(
                    actionPrograms(in:)
                )

        default:
            return []
        }
    }

    private func actionPrograms(
        in modifier: PreviewModifier
    ) -> [PreviewActionProgram] {
        switch modifier {
        case .sheet(_, let content),
             .fullScreenCover(_, let content):
            return actionPrograms(
                in: content
            )

        case .sheetWithOnDismiss(
            _,
            let program,
            let content
        ),
        .fullScreenCoverWithOnDismiss(
            _,
            let program,
            let content
        ):
            return [program] +
                actionPrograms(
                    in: content
                )

        default:
            return []
        }
    }
}
