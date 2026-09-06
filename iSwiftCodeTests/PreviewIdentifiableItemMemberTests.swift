import Foundation
import XCTest
@testable import iSwiftCode

final class PreviewIdentifiableItemMemberTests:
    XCTestCase {
    private func preview(
        _ source: String
    ) throws -> PreviewProviderResult {
        try SwiftUIIdentifiableItemMemberPreviewProvider()
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

    func testSheetDirectMemberTextIsLowered() throws {
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
                VStack {
                    Text(item.title)
                    Text(item.id)
                }
            }
            """
        )

        XCTAssertTrue(result.succeeded)

        let memberNodes =
            collectMemberNodes(
                result.document?.root
            )

        XCTAssertTrue(
            memberNodes.contains(
                PreviewMemberNode(
                    stateName:
                        "selectedItem",
                    memberName:
                        "title"
                )
            )
        )

        XCTAssertTrue(
            memberNodes.contains(
                PreviewMemberNode(
                    stateName:
                        "selectedItem",
                    memberName:
                        "id"
                )
            )
        )
    }

    func testFullScreenDirectMemberTextIsLowered() throws {
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
                Text(item.title)
            }
            """
        )

        XCTAssertTrue(result.succeeded)

        XCTAssertTrue(
            collectMemberNodes(
                result.document?.root
            ).contains(
                PreviewMemberNode(
                    stateName:
                        "selectedItem",
                    memberName:
                        "title"
                )
            )
        )
    }

    func testPrimitiveItemMemberAccessIsRejected() throws {
        let result = try preview(
            """
            @State private var selectedItem: String? = nil

            VStack {
                Text("Ready")
            }
            .sheet(item: $selectedItem) { item in
                Text(item.count)
            }
            """
        )

        XCTAssertFalse(result.succeeded)
        XCTAssertTrue(
            result.diagnostics
                .first?
                .message
                .contains(
                    "Identifiable"
                ) == true
        )
    }

    func testPlainTextItemBehaviorStillUsesOldPath() throws {
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
        XCTAssertTrue(
            collectMemberNodes(
                result.document?.root
            ).isEmpty
        )
    }

    private func collectMemberNodes(
        _ node: PreviewNode?
    ) -> [PreviewMemberNode] {
        guard let node else {
            return []
        }

        switch node {
        case .itemMemberText(
            let stateName,
            let memberName
        ):
            return [
                PreviewMemberNode(
                    stateName: stateName,
                    memberName: memberName
                )
            ]

        case .vStack(let children),
             .hStack(let children),
             .zStack(let children),
             .scrollView(let children),
             .list(let children),
             .navigationStack(let children):
            return children.flatMap {
                collectMemberNodes($0)
            }

        case .navigationLink(
            _,
            let destination
        ):
            return collectMemberNodes(
                destination
            )

        case .modified(
            let base,
            let modifiers
        ):
            var result =
                collectMemberNodes(base)

            for modifier in modifiers {
                result +=
                    collectMemberNodes(
                        modifier
                    )
            }

            return result

        default:
            return []
        }
    }

    private func collectMemberNodes(
        _ modifier: PreviewModifier
    ) -> [PreviewMemberNode] {
        switch modifier {
        case .sheet(
            _,
            let content
        ),
        .fullScreenCover(
            _,
            let content
        ):
            return collectMemberNodes(
                content
            )

        case .sheetWithOnDismiss(
            _,
            _,
            let content
        ),
        .fullScreenCoverWithOnDismiss(
            _,
            _,
            let content
        ):
            return collectMemberNodes(
                content
            )

        default:
            return []
        }
    }
}

private struct PreviewMemberNode:
    Equatable {
    let stateName: String
    let memberName: String
}
