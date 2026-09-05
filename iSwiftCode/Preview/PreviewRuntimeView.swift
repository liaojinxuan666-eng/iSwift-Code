import SwiftUI

struct PreviewRuntimeView: View {
    let document: PreviewDocument

    var body: some View {
        PreviewNodeView(node: document.root)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .systemBackground))
    }
}

private struct PreviewNodeView: View {
    let node: PreviewNode

    @ViewBuilder
    var body: some View {
        switch node {
        case .text(let value):
            Text(value)

        case .button(let title):
            Button(title) {}
                .buttonStyle(.borderedProminent)

        case .image(let systemName):
            Image(systemName: systemName)
                .font(.largeTitle)

        case .spacer:
            Spacer(minLength: 8)

        case .vStack(let children):
            VStack(spacing: 12) {
                childViews(children)
            }
            .padding()

        case .hStack(let children):
            HStack(spacing: 12) {
                childViews(children)
            }
            .padding()

        case .zStack(let children):
            ZStack {
                childViews(children)
            }
            .padding()

        case .scrollView(let children):
            ScrollView {
                VStack(spacing: 12) {
                    childViews(children)
                }
                .padding()
            }

        case .list(let children):
            List {
                childViews(children)
            }

        case .navigationStack(let children):
            NavigationStack {
                VStack(spacing: 12) {
                    childViews(children)
                }
                .padding()
            }
        }
    }

    @ViewBuilder
    private func childViews(_ children: [PreviewNode]) -> some View {
        ForEach(Array(children.enumerated()), id: \.offset) { item in
            PreviewNodeView(node: item.element)
        }
    }
}
