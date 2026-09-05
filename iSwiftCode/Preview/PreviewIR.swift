import Foundation

indirect enum PreviewNode: Equatable, Sendable {
    case text(String)
    case button(title: String)
    case image(systemName: String)
    case spacer
    case vStack(children: [PreviewNode])
    case hStack(children: [PreviewNode])
    case zStack(children: [PreviewNode])
    case scrollView(children: [PreviewNode])
    case list(children: [PreviewNode])
    case navigationStack(children: [PreviewNode])
}

struct PreviewDocument: Equatable, Sendable {
    let root: PreviewNode
    let sourceFilePath: String?
    let title: String?

    init(
        root: PreviewNode,
        sourceFilePath: String? = nil,
        title: String? = nil
    ) {
        self.root = root
        self.sourceFilePath = sourceFilePath
        self.title = title
    }
}
