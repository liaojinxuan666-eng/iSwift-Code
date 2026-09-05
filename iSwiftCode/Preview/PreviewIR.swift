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

enum PreviewStateValue: Equatable, Sendable {
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

struct PreviewStateDefinition: Equatable, Sendable {
    let name: String
    let initialValue: PreviewStateValue
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

    case button(title: String)
    case image(systemName: String)
    case spacer
    case vStack(children: [PreviewNode])
    case hStack(children: [PreviewNode])
    case zStack(children: [PreviewNode])
    case scrollView(children: [PreviewNode])
    case list(children: [PreviewNode])
    case navigationStack(children: [PreviewNode])
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
