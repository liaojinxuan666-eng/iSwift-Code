import SwiftUI

struct PreviewRuntimeView: View {
    let document: PreviewDocument

    @StateObject private var stateStore: PreviewStateStore

    init(document: PreviewDocument) {
        self.document = document
        _stateStore = StateObject(
            wrappedValue: PreviewStateStore(
                definitions: document.stateDefinitions
            )
        )
    }

    var body: some View {
        PreviewNodeView(
            node: document.root,
            stateStore: stateStore
        )
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
        .background(
            Color(uiColor: .systemBackground)
        )
        .onChange(
            of: document.stateDefinitions
        ) { _, definitions in
            stateStore.reload(
                definitions: definitions
            )
        }
    }
}

private struct PreviewNodeView: View {
    let node: PreviewNode

    @ObservedObject var stateStore: PreviewStateStore

    var body: some View {
        render(node)
    }

    private func render(
        _ node: PreviewNode
    ) -> AnyView {
        switch node {
        case .text(let value):
            return AnyView(
                Text(value)
            )

        case .stateText(let name):
            return AnyView(
                Text(
                    stateStore.displayText(
                        for: name
                    )
                )
            )

        case .interpolatedText(let template):
            return AnyView(
                Text(
                    stateStore.resolveInterpolations(
                        in: template
                    )
                )
            )

        case .textField(let prompt, let reference):
            return AnyView(
                TextField(
                    prompt,
                    text: stringBinding(
                        for: reference.stateName
                    )
                )
                .textFieldStyle(.roundedBorder)
            )

        case .toggle(let title, let reference):
            return AnyView(
                Toggle(
                    title,
                    isOn: boolBinding(
                        for: reference.stateName
                    )
                )
            )

        case .picker(
            let title,
            let reference,
            let options
        ):
            return AnyView(
                Picker(
                    title,
                    selection: selectionBinding(
                        for: reference.stateName
                    )
                ) {
                    ForEach(
                        Array(options.enumerated()),
                        id: \.offset
                    ) { item in
                        Text(item.element.title)
                            .tag(item.element.value)
                    }
                }
                .pickerStyle(.menu)
            )

        case .button(let title):
            return AnyView(
                Button(title) {}
                    .buttonStyle(.borderedProminent)
            )

        case .actionButton(
            let title,
            let program
        ):
            return AnyView(
                Button(title) {
                    _ = stateStore.perform(program)
                }
                .buttonStyle(.borderedProminent)
            )

        case .image(let systemName):
            return AnyView(
                Image(systemName: systemName)
                    .font(.largeTitle)
            )

        case .spacer:
            return AnyView(
                Spacer(minLength: 8)
            )

        case .vStack(let children):
            return renderVStack(
                children: children,
                modifiers: []
            )

        case .hStack(let children):
            return renderHStack(
                children: children,
                modifiers: []
            )

        case .zStack(let children):
            return renderZStack(
                children: children,
                modifiers: []
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

        case .navigationLink(
            let title,
            let destination
        ):
            return AnyView(
                NavigationLink {
                    PreviewNodeView(
                        node: destination,
                        stateStore: stateStore
                    )
                } label: {
                    Text(title)
                }
            )

        case .modified(
            let base,
            let modifiers
        ):
            switch base {
            case .vStack(let children):
                return renderVStack(
                    children: children,
                    modifiers: modifiers
                )

            case .hStack(let children):
                return renderHStack(
                    children: children,
                    modifiers: modifiers
                )

            case .zStack(let children):
                return renderZStack(
                    children: children,
                    modifiers: modifiers
                )

            default:
                var view = render(base)

                for modifier in modifiers {
                    view = apply(
                        modifier,
                        to: view
                    )
                }

                return view
            }
        }
    }

    private func renderVStack(
        children: [PreviewNode],
        modifiers: [PreviewModifier]
    ) -> AnyView {
        let alignment = modifiers
            .compactMap {
                modifier
                    -> PreviewHorizontalAlignment? in
                if case .horizontalAlignment(
                    let value
                ) = modifier {
                    return value
                }

                return nil
            }
            .last ?? .center

        let spacing = modifiers
            .compactMap {
                modifier -> Double? in
                if case .stackSpacing(
                    let value
                ) = modifier {
                    return value
                }

                return nil
            }
            .last

        var view = AnyView(
            VStack(
                alignment:
                    swiftUIHorizontalAlignment(
                        alignment
                    ),
                spacing: cgFloat(spacing)
            ) {
                childViews(children)
            }
        )

        for modifier in modifiers
            where !isStackLayoutModifier(
                modifier
            ) {
            view = apply(
                modifier,
                to: view
            )
        }

        return view
    }

    private func renderHStack(
        children: [PreviewNode],
        modifiers: [PreviewModifier]
    ) -> AnyView {
        let alignment = modifiers
            .compactMap {
                modifier
                    -> PreviewVerticalAlignment? in
                if case .verticalAlignment(
                    let value
                ) = modifier {
                    return value
                }

                return nil
            }
            .last ?? .center

        let spacing = modifiers
            .compactMap {
                modifier -> Double? in
                if case .stackSpacing(
                    let value
                ) = modifier {
                    return value
                }

                return nil
            }
            .last

        var view = AnyView(
            HStack(
                alignment:
                    swiftUIVerticalAlignment(
                        alignment
                    ),
                spacing: cgFloat(spacing)
            ) {
                childViews(children)
            }
        )

        for modifier in modifiers
            where !isStackLayoutModifier(
                modifier
            ) {
            view = apply(
                modifier,
                to: view
            )
        }

        return view
    }

    private func renderZStack(
        children: [PreviewNode],
        modifiers: [PreviewModifier]
    ) -> AnyView {
        let alignment = modifiers
            .compactMap {
                modifier
                    -> PreviewAlignment? in
                if case .zStackAlignment(
                    let value
                ) = modifier {
                    return value
                }

                return nil
            }
            .last ?? .center

        var view = AnyView(
            ZStack(
                alignment:
                    swiftUIAlignment(
                        alignment
                    )
            ) {
                childViews(children)
            }
        )

        for modifier in modifiers
            where !isStackLayoutModifier(
                modifier
            ) {
            view = apply(
                modifier,
                to: view
            )
        }

        return view
    }

    @ViewBuilder
    private func childViews(
        _ children: [PreviewNode]
    ) -> some View {
        ForEach(
            Array(children.enumerated()),
            id: \.offset
        ) { item in
            PreviewNodeView(
                node: item.element,
                stateStore: stateStore
            )
        }
    }

    private func stringBinding(
        for stateName: String
    ) -> Binding<String> {
        Binding(
            get: {
                stateStore.stringValue(
                    for: stateName
                )
            },
            set: { value in
                stateStore.setValue(
                    .string(value),
                    for: stateName
                )
            }
        )
    }

    private func boolBinding(
        for stateName: String
    ) -> Binding<Bool> {
        Binding(
            get: {
                stateStore.boolValue(
                    for: stateName
                )
            },
            set: { value in
                stateStore.setValue(
                    .bool(value),
                    for: stateName
                )
            }
        )
    }

    private func selectionBinding(
        for stateName: String
    ) -> Binding<PreviewStateValue> {
        Binding(
            get: {
                stateStore.value(
                    for: stateName
                ) ?? .string("")
            },
            set: { value in
                stateStore.setValue(
                    value,
                    for: stateName
                )
            }
        )
    }

    private func apply(
        _ modifier: PreviewModifier,
        to view: AnyView
    ) -> AnyView {
        switch modifier {
        case .padding(let amount):
            if let amount {
                return AnyView(
                    view.padding(
                        CGFloat(amount)
                    )
                )
            }

            return AnyView(
                view.padding()
            )

        case .frame(let frame):
            var result = view

            if frame.width != nil ||
                frame.height != nil {
                let width: CGFloat? =
                    cgFloat(frame.width)
                let height: CGFloat? =
                    cgFloat(frame.height)

                result = AnyView(
                    result.frame(
                        width: width,
                        height: height
                    )
                )
            }

            if frame.maxWidth != nil ||
                frame.maxHeight != nil {
                let maxWidth: CGFloat? =
                    dimension(
                        frame.maxWidth
                    )
                let maxHeight: CGFloat? =
                    dimension(
                        frame.maxHeight
                    )

                result = AnyView(
                    result.frame(
                        maxWidth: maxWidth,
                        maxHeight: maxHeight
                    )
                )
            }

            return result

        case .foregroundStyle(let color):
            return AnyView(
                view.foregroundStyle(
                    swiftUIColor(color)
                )
            )

        case .background(let color):
            return AnyView(
                view.background(
                    swiftUIColor(color)
                )
            )

        case .font(let font):
            return AnyView(
                view.font(
                    swiftUIFont(font)
                )
            )

        case .cornerRadius(let radius):
            return AnyView(
                view.cornerRadius(
                    CGFloat(radius)
                )
            )

        case .navigationTitle(let title):
            return AnyView(
                view.navigationTitle(title)
            )

        case .sheet(
            let reference,
            let content
        ):
            return AnyView(
                view.sheet(
                    isPresented: boolBinding(
                        for: reference.stateName
                    )
                ) {
                    PreviewNodeView(
                        node: content,
                        stateStore: stateStore
                    )
                }
            )

        case .sheetWithOnDismiss(
            let reference,
            let program,
            let content
        ):
            return AnyView(
                view.sheet(
                    isPresented: boolBinding(
                        for: reference.stateName
                    ),
                    onDismiss: {
                        _ = stateStore.perform(program)
                    }
                ) {
                    PreviewNodeView(
                        node: content,
                        stateStore: stateStore
                    )
                }
            )

        case .stackSpacing,
             .horizontalAlignment,
             .verticalAlignment,
             .zStackAlignment:
            return view
        }
    }

    private func isStackLayoutModifier(
        _ modifier: PreviewModifier
    ) -> Bool {
        switch modifier {
        case .stackSpacing,
             .horizontalAlignment,
             .verticalAlignment,
             .zStackAlignment:
            return true

        default:
            return false
        }
    }

    private func cgFloat(
        _ value: Double?
    ) -> CGFloat? {
        guard let value else {
            return nil
        }

        return CGFloat(value)
    }

    private func dimension(
        _ value: PreviewDimension?
    ) -> CGFloat? {
        guard let value else {
            return nil
        }

        switch value {
        case .points(let points):
            return CGFloat(points)

        case .infinity:
            return CGFloat.infinity
        }
    }

    private func swiftUIHorizontalAlignment(
        _ alignment:
            PreviewHorizontalAlignment
    ) -> HorizontalAlignment {
        switch alignment {
        case .leading:
            return .leading

        case .center:
            return .center

        case .trailing:
            return .trailing
        }
    }

    private func swiftUIVerticalAlignment(
        _ alignment:
            PreviewVerticalAlignment
    ) -> VerticalAlignment {
        switch alignment {
        case .top:
            return .top

        case .center:
            return .center

        case .bottom:
            return .bottom

        case .firstTextBaseline:
            return .firstTextBaseline

        case .lastTextBaseline:
            return .lastTextBaseline
        }
    }

    private func swiftUIAlignment(
        _ alignment: PreviewAlignment
    ) -> Alignment {
        switch alignment {
        case .center:
            return .center

        case .leading:
            return .leading

        case .trailing:
            return .trailing

        case .top:
            return .top

        case .bottom:
            return .bottom

        case .topLeading:
            return .topLeading

        case .topTrailing:
            return .topTrailing

        case .bottomLeading:
            return .bottomLeading

        case .bottomTrailing:
            return .bottomTrailing
        }
    }

    private func swiftUIColor(
        _ color: PreviewColor
    ) -> Color {
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

    private func swiftUIFont(
        _ font: PreviewFont
    ) -> Font {
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
