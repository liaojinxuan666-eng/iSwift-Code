import Foundation
import XCTest
@testable import iSwiftCode

final class PreviewIdentifiableItemInterpolationTests:
    XCTestCase {
    private func preview(
        _ source: String
    ) throws -> PreviewProviderResult {
        try SwiftUIIdentifiableItemInterpolationPreviewProvider()
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

    func testSheetMemberInterpolationIsLowered() throws {
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
                Text("Title: \\(item.title)")
                Text("ID: \\(item.id)")
            }
            """
        )

        XCTAssertTrue(result.succeeded)

        let nodes =
            collectInterpolationNodes(
                result.document?.root
            )

        XCTAssertTrue(
            nodes.contains(
                where: {
                    $0.template.contains(
                        "Title: "
                    ) &&
                    $0.members.contains(
                        PreviewInterpolationMember(
                            stateName:
                                "selectedItem",
                            memberName:
                                "title"
                        )
                    )
                }
            )
        )

        XCTAssertTrue(
            nodes.contains(
                where: {
                    $0.template.contains(
                        "ID: "
                    ) &&
                    $0.members.contains(
                        PreviewInterpolationMember(
                            stateName:
                                "selectedItem",
                            memberName:
                                "id"
                        )
                    )
                }
            )
        )
    }

    func testMultipleMembersInOneTextAreLowered() throws {
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
                Text("\\(item.id): \\(item.title)")
            }
            """
        )

        XCTAssertTrue(result.succeeded)

        let node = try XCTUnwrap(
            collectInterpolationNodes(
                result.document?.root
            ).first
        )

        XCTAssertEqual(
            Set(node.members),
            Set([
                PreviewInterpolationMember(
                    stateName:
                        "selectedItem",
                    memberName:
                        "id"
                ),
                PreviewInterpolationMember(
                    stateName:
                        "selectedItem",
                    memberName:
                        "title"
                )
            ])
        )
    }

    func testFullScreenMemberInterpolationIsLowered() throws {
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
                Text("Current: \\(item.title)")
            }
            """
        )

        XCTAssertTrue(result.succeeded)

        XCTAssertTrue(
            collectInterpolationNodes(
                result.document?.root
            ).contains(
                where: {
                    $0.members.contains(
                        PreviewInterpolationMember(
                            stateName:
                                "selectedItem",
                            memberName:
                                "title"
                        )
                    )
                }
            )
        )
    }

    func testPrimitiveItemInterpolationStaysOnExistingPath() throws {
        let result = try preview(
            """
            @State private var selectedItem: String? = nil

            VStack {
                Text("Ready")
            }
            .sheet(item: $selectedItem) { item in
                Text("Value: \\(item)")
            }
            """
        )

        XCTAssertTrue(result.succeeded)
        XCTAssertTrue(
            collectInterpolationNodes(
                result.document?.root
            ).isEmpty
        )
    }

    func testDirectItemMemberStillUsesExistingMemberPath() throws {
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
                Text(item.title)
            }
            """
        )

        XCTAssertTrue(result.succeeded)
        XCTAssertTrue(
            collectInterpolationNodes(
                result.document?.root
            ).isEmpty
        )
        XCTAssertTrue(
            containsDirectMemberNode(
                result.document?.root
            )
        )
    }

    private func collectInterpolationNodes(
        _ node: PreviewNode?
    ) -> [PreviewInterpolationNode] {
        guard let node else {
            return []
        }

        switch node {
        case .itemMemberInterpolatedText(
            let template,
            let members
        ):
            return [
                PreviewInterpolationNode(
                    template: template,
                    members: members.map {
                        PreviewInterpolationMember(
                            stateName:
                                $0.stateName,
                            memberName:
                                $0.memberName
                        )
                    }
                )
            ]

        case .vStack(let children),
             .hStack(let children),
             .zStack(let children),
             .scrollView(let children),
             .list(let children),
             .navigationStack(let children):
            return children.flatMap {
                collectInterpolationNodes($0)
            }

        case .navigationLink(
            _,
            let destination
        ):
            return collectInterpolationNodes(
                destination
            )

        case .modified(
            let base,
            let modifiers
        ):
            var result =
                collectInterpolationNodes(base)

            for modifier in modifiers {
                result +=
                    collectInterpolationNodes(
                        modifier
                    )
            }

            return result

        default:
            return []
        }
    }

    private func collectInterpolationNodes(
        _ modifier: PreviewModifier
    ) -> [PreviewInterpolationNode] {
        switch modifier {
        case .sheet(
            _,
            let content
        ),
        .fullScreenCover(
            _,
            let content
        ):
            return collectInterpolationNodes(
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
            return collectInterpolationNodes(
                content
            )

        default:
            return []
        }
    }

    private func containsDirectMemberNode(
        _ node: PreviewNode?
    ) -> Bool {
        guard let node else {
            return false
        }

        switch node {
        case .itemMemberText:
            return true

        case .vStack(let children),
             .hStack(let children),
             .zStack(let children),
             .scrollView(let children),
             .list(let children),
             .navigationStack(let children):
            return children.contains {
                containsDirectMemberNode($0)
            }

        case .navigationLink(
            _,
            let destination
        ):
            return containsDirectMemberNode(
                destination
            )

        case .modified(
            let base,
            let modifiers
        ):
            if containsDirectMemberNode(base) {
                return true
            }

            return modifiers.contains {
                containsDirectMemberNode($0)
            }

        default:
            return false
        }
    }

    private func containsDirectMemberNode(
        _ modifier: PreviewModifier
    ) -> Bool {
        switch modifier {
        case .sheet(
            _,
            let content
        ),
        .fullScreenCover(
            _,
            let content
        ):
            return containsDirectMemberNode(
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
            return containsDirectMemberNode(
                content
            )

        default:
            return false
        }
    }
}

private struct PreviewInterpolationNode {
    let template: String
    let members: [PreviewInterpolationMember]
}

private struct PreviewInterpolationMember:
    Equatable,
    Hashable {
    let stateName: String
    let memberName: String
}
