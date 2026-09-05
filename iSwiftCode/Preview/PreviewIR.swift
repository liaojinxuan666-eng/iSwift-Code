import Foundation

enum PreviewColor: String, Codable, CaseIterable, Equatable, Sendable {
    case primary
    case secondary
    case red
    case orange
    case yellow
    case green
    case mint
    case teal
    case cyan
    case blue
    case indigo
    case purple
    case pink
    case brown
    case gray
    case black
    case white
    case clear
}

enum PreviewFont: String, Codable, CaseIterable, Equatable, Sendable {
    case largeTitle
    case title
    case title2
    case title3
    case headline
    case subheadline
    case body
    case callout
    case footnote
    case caption
    case caption2
}

enum PreviewHorizontalAlignment: String, Codable, CaseIterable, Equatable, Sendable {
    case leading
    case center
    case trailing
}

enum PreviewVerticalAlignment: String, Codable, CaseIterable, Equatable, Sendable {
    case top
    case center
    case bottom
    case firstTextBaseline
    case lastTextBaseline
}

enum PreviewAlignment: String, Codable, CaseIterable, Equatable, Sendable {
    case center
    case leading
    case trailing
    case top
    case bottom
    case topLeading
    case topTrailing
    case bottomLeading
    case bottomTrailing
}

enum PreviewStateValue: Equatable, Hashable, Sendable {
    case string(String)
    case bool(Bool)
    case number(Double)

    /// Optional primitive preview state.
    ///
    /// These cases preserve the wrapped value kind even when the current value
    /// is nil. That is required by item-driven presentation such as
    /// `.sheet(item:)`, where nil means "not presented" and a wrapped value
    /// means "present this item".
    case optionalString(String?)
    case optionalBool(Bool?)
    case optionalNumber(Double?)

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

        case .optionalString(let value):
            return value ?? ""

        case .optionalBool(let value):
            guard let value else {
                return ""
            }
            return value ? "true" : "false"

        case .optionalNumber(let value):
            guard let value else {
                return ""
            }
            if value.rounded() == value {
                return String(Int(value))
            }
            return String(value)
        }
    }

    var isNilOptional: Bool {
        switch self {
        case .optionalString(nil),
             .optionalBool(nil),
             .optionalNumber(nil):
            return true

        default:
            return false
        }
    }
}

struct PreviewStateDefinition: Equatable, Sendable {
    let name: String
    let initialValue: PreviewStateValue
}

/// Portable reference to mutable preview state.
///
/// This is intentionally not SwiftUI.Binding. Providers emit the reference and
/// the signed runtime decides how to expose a native binding for each control.
struct PreviewBindingReference: Equatable, Sendable {
    let stateName: String
}

struct PreviewPickerOption: Equatable, Hashable, Sendable {
    let title: String
    let value: PreviewStateValue
}

enum PreviewDimension: Equatable, Sendable {
    case points(Double)
    case infinity
}

struct PreviewFrame: Equatable, Sendable {
    let width: Double?
    let height: Double?
    let maxWidth: PreviewDimension?
    let maxHeight: PreviewDimension?

    init(
        width: Double? = nil,
        height: Double? = nil,
        maxWidth: PreviewDimension? = nil,
        maxHeight: PreviewDimension? = nil
    ) {
        self.width = width
        self.height = height
        self.maxWidth = maxWidth
        self.maxHeight = maxHeight
    }
}

enum PreviewModifier: Equatable, Sendable {
    case padding(Double?)
    case frame(PreviewFrame)
    case foregroundStyle(PreviewColor)
    case background(PreviewColor)
    case font(PreviewFont)
    case cornerRadius(Double)
    case navigationTitle(String)
    case sheet(
        isPresented: PreviewBindingReference,
        content: PreviewNode
    )

    /// Sheet presentation with a constrained dismissal action.
    ///
    /// The runtime never receives an executable Swift closure. Providers lower
    /// supported dismissal mutations to PreviewActionProgram first.
    case sheetWithOnDismiss(
        isPresented: PreviewBindingReference,
        onDismiss: PreviewActionProgram,
        content: PreviewNode
    )

    /// Full-screen presentation driven by portable Bool preview state.
    case fullScreenCover(
        isPresented: PreviewBindingReference,
        content: PreviewNode
    )

    /// Full-screen presentation with a constrained dismissal action.
    ///
    /// As with sheetWithOnDismiss, the runtime receives portable actions rather
    /// than an executable source closure.
    case fullScreenCoverWithOnDismiss(
        isPresented: PreviewBindingReference,
        onDismiss: PreviewActionProgram,
        content: PreviewNode
    )

    case stackSpacing(Double)
    case horizontalAlignment(PreviewHorizontalAlignment)
    case verticalAlignment(PreviewVerticalAlignment)
    case zStackAlignment(PreviewAlignment)
}

indirect enum PreviewNode: Equatable, Sendable {
    case text(String)

    /// Text driven by one preview-state value, for example `Text(title)`.
    case stateText(name: String)

    /// A string literal containing simple state interpolation, for example
    /// `Text("Count: \(count)")`.
    case interpolatedText(String)

    case textField(
        prompt: String,
        text: PreviewBindingReference
    )
    case toggle(
        title: String,
        isOn: PreviewBindingReference
    )
    case picker(
        title: String,
        selection: PreviewBindingReference,
        options: [PreviewPickerOption]
    )

    case button(title: String)
    case actionButton(
        title: String,
        program: PreviewActionProgram
    )
    case image(systemName: String)
    case spacer
    case vStack(children: [PreviewNode])
    case hStack(children: [PreviewNode])
    case zStack(children: [PreviewNode])
    case scrollView(children: [PreviewNode])
    case list(children: [PreviewNode])
    case navigationStack(children: [PreviewNode])
    case navigationLink(
        title: String,
        destination: PreviewNode
    )
    case modified(base: PreviewNode, modifiers: [PreviewModifier])
}

extension PreviewNode {
    func applying(_ modifier: PreviewModifier) -> PreviewNode {
        switch self {
        case .modified(let base, let modifiers):
            return .modified(
                base: base,
                modifiers: modifiers + [modifier]
            )

        default:
            return .modified(
                base: self,
                modifiers: [modifier]
            )
        }
    }
}

struct PreviewDocument: Equatable, Sendable {
    let root: PreviewNode
    let stateDefinitions: [PreviewStateDefinition]
    let sourceFilePath: String?
    let title: String?

    init(
        root: PreviewNode,
        stateDefinitions: [PreviewStateDefinition] = [],
        sourceFilePath: String? = nil,
        title: String? = nil
    ) {
        self.root = root
        self.stateDefinitions = stateDefinitions
        self.sourceFilePath = sourceFilePath
        self.title = title
    }
}
