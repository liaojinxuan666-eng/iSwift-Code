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

    var body: some View {
        render(node)
    }

    private func render(_ node: PreviewNode) -> AnyView {
        switch node {
        case .text(let value):
            return AnyView(Text(value))

        case .button(let title):
            return AnyView(
                Button(title) {}
                    .buttonStyle(.borderedProminent)
            )

        case .image(let systemName):
            return AnyView(
                Image(systemName: systemName)
                    .font(.largeTitle)
            )

        case .spacer:
            return AnyView(Spacer(minLength: 8))

        case .vStack(let children):
            return AnyView(
                VStack(spacing: 12) {
                    childViews(children)
                }
            )

        case .hStack(let children):
            return AnyView(
                HStack(spacing: 12) {
                    childViews(children)
                }
            )

        case .zStack(let children):
            return AnyView(
                ZStack {
                    childViews(children)
                }
            )

        case .scrollView(let children):
            return AnyView(
                ScrollView {
                    VStack(spacing: 12) {
                        childViews(children)
                    }
                }
            )

        case .list(let children):
            return AnyView(
                List {
                    childViews(children)
                }
            )

        case .navigationStack(let children):
            return AnyView(
                NavigationStack {
                    VStack(spacing: 12) {
                        childViews(children)
                    }
                }
            )

        case .modified(let base, let modifiers):
            var view = render(base)
            for modifier in modifiers {
                view = apply(modifier, to: view)
            }
            return view
        }
    }

    @ViewBuilder
    private func childViews(_ children: [PreviewNode]) -> some View {
        ForEach(Array(children.enumerated()), id: \.offset) { item in
            PreviewNodeView(node: item.element)
        }
    }

    private func apply(
        _ modifier: PreviewModifier,
        to view: AnyView
    ) -> AnyView {
        switch modifier {
        case .padding(let amount):
            if let amount {
                return AnyView(view.padding(CGFloat(amount)))
            }
            return AnyView(view.padding())

        case .frame(let frame):
            var result = view

            if frame.width != nil || frame.height != nil {
                let width: CGFloat? = cgFloat(frame.width)
                let height: CGFloat? = cgFloat(frame.height)

                result = AnyView(
                    result.frame(
                        width: width,
                        height: height
                    )
                )
            }

            if frame.maxWidth != nil || frame.maxHeight != nil {
                let maxWidth: CGFloat? = dimension(frame.maxWidth)
                let maxHeight: CGFloat? = dimension(frame.maxHeight)

                result = AnyView(
                    result.frame(
                        maxWidth: maxWidth,
                        maxHeight: maxHeight
                    )
                )
            }

            return result

        case .foregroundStyle(let color):
            return AnyView(view.foregroundStyle(swiftUIColor(color)))

        case .background(let color):
            return AnyView(view.background(swiftUIColor(color)))

        case .font(let font):
            return AnyView(view.font(swiftUIFont(font)))

        case .cornerRadius(let radius):
            return AnyView(view.cornerRadius(CGFloat(radius)))
        }
    }

    private func cgFloat(_ value: Double?) -> CGFloat? {
        guard let value else { return nil }
        return CGFloat(value)
    }

    private func dimension(_ value: PreviewDimension?) -> CGFloat? {
        guard let value else { return nil }
        switch value {
        case .points(let points):
            return CGFloat(points)
        case .infinity:
            return CGFloat.infinity
        }
    }

    private func swiftUIColor(_ color: PreviewColor) -> Color {
        switch color {
        case .primary: return .primary
        case .secondary: return .secondary
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .mint: return .mint
        case .teal: return .teal
        case .cyan: return .cyan
        case .blue: return .blue
        case .indigo: return .indigo
        case .purple: return .purple
        case .pink: return .pink
        case .brown: return .brown
        case .gray: return .gray
        case .black: return .black
        case .white: return .white
        case .clear: return .clear
        }
    }

    private func swiftUIFont(_ font: PreviewFont) -> Font {
        switch font {
        case .largeTitle: return .largeTitle
        case .title: return .title
        case .title2: return .title2
        case .title3: return .title3
        case .headline: return .headline
        case .subheadline: return .subheadline
        case .body: return .body
        case .callout: return .callout
        case .footnote: return .footnote
        case .caption: return .caption
        case .caption2: return .caption2
        }
    }
}
