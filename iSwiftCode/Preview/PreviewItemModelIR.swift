import Foundation

/// Portable scalar value stored inside an Identifiable preview item.
///
/// This remains independent from SwiftUI and Foundation model objects so the
/// preview provider can lower user source into signed-runtime data instead of
/// executing user-defined model code.
enum PreviewItemMemberValue: Equatable, Hashable, Sendable {
    case string(String)
    case bool(Bool)
    case number(Double)

    var displayText: String {
        switch self {
        case .string(let value):
            return value

        case .bool(let value):
            return value ? "true" : "false"

        case .number(let value):
            if value.rounded() == value {
                return String(Int(value))
            }
            return String(value)
        }
    }
}

/// One stored member of a portable Identifiable preview item.
struct PreviewItemMember: Equatable, Hashable, Sendable {
    let name: String
    let value: PreviewItemMemberValue
}

/// Portable IR for a source model conforming to `Identifiable`.
///
/// `id` is kept separately because item-driven SwiftUI presentation requires a
/// stable identity. Other model members stay ordered so future source lowering
/// can preserve deterministic output and support `item.member` lookups.
struct PreviewIdentifiableItem: Equatable, Hashable, Sendable {
    let typeName: String
    let id: PreviewItemMemberValue
    let members: [PreviewItemMember]

    init(
        typeName: String,
        id: PreviewItemMemberValue,
        members: [PreviewItemMember] = []
    ) {
        self.typeName = typeName
        self.id = id
        self.members = members
    }

    /// Resolves one portable model member without invoking source code.
    ///
    /// Identifiable's `id` is always exposed even though it is stored
    /// separately from the regular member list.
    func member(
        named name: String
    ) -> PreviewItemMemberValue? {
        if name == "id" {
            return id
        }

        return members.last(
            where: { $0.name == name }
        )?.value
    }

    func displayText(
        forMember name: String
    ) -> String? {
        member(named: name)?.displayText
    }
}

/// Typed optional item state foundation for future `.sheet(item:)` and
/// `.fullScreenCover(item:)` model lowering.
///
/// The current primitive item path remains unchanged. A later provider layer
/// will bridge this portable value into PreviewStateValue and action lowering.
struct PreviewOptionalIdentifiableItemState: Equatable, Hashable, Sendable {
    let itemTypeName: String
    let item: PreviewIdentifiableItem?

    init(
        itemTypeName: String,
        item: PreviewIdentifiableItem? = nil
    ) {
        self.itemTypeName = itemTypeName
        self.item = item
    }

    var isPresented: Bool {
        item != nil
    }

    func presenting(
        _ item: PreviewIdentifiableItem
    ) -> PreviewOptionalIdentifiableItemState {
        PreviewOptionalIdentifiableItemState(
            itemTypeName: itemTypeName,
            item: item
        )
    }

    func clearing() -> PreviewOptionalIdentifiableItemState {
        PreviewOptionalIdentifiableItemState(
            itemTypeName: itemTypeName,
            item: nil
        )
    }
}
