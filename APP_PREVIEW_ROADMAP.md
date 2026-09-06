# App Preview Roadmap — Locked

Status: **0.1.3 implementation in progress**

App Preview keeps three separate product paths:

`Run Code | Preview App | Build IPA`

## Completed

- portable Preview IR and signed native runtime
- Live Preview
- primitive and typed optional primitive `@State`
- TextField / Toggle / Picker bindings
- constrained Button action runtime
- NavigationStack / NavigationLink
- navigationTitle
- `.sheet(isPresented:)` and constrained `onDismiss`
- `.fullScreenCover(isPresented:)` and constrained `onDismiss`
- `.sheet(item:)` for optional primitive item state
- `.fullScreenCover(item:)` for optional primitive item state
- built-in Bool and item presentation demos
- portable Identifiable item-model IR foundation
- Identifiable item state/action bridge
- constrained Identifiable source-model parsing
- typed optional custom-model `@State` recognition
- constrained Identifiable model-constructor action lowering
- runtime custom Identifiable item presentation bridge
- direct `Text(item.member)` lowering for item presentations

## Current custom item path

The first direct member form now lowers portably:

```swift
struct DetailItem: Identifiable {
    let id: Int
    let title: String
}

@State private var selectedItem: DetailItem? = nil

Button("Open") {
    selectedItem = DetailItem(
        id: 1,
        title: "Details"
    )
}
.sheet(item: $selectedItem) { item in
    Text(item.title)
    Text(item.id)
}
```

The presentation member expressions become:

```text
item.title
    ↓
PreviewNode.itemMemberText(
    stateName: "selectedItem",
    memberName: "title"
)
    ↓
PreviewStateStore optional Identifiable item
    ↓
PreviewIdentifiableItem.member(named:)
    ↓
native Text
```

No source property getter is executed.

The same direct-member form is supported for
`.fullScreenCover(item:)`.

Primitive item presentation remains on its existing path. Direct
`item.member` requires a custom Identifiable optional state.

## Next preview layers

1. member interpolation such as `Text("\(item.title)")`
2. validation diagnostics for unknown custom members
3. richer custom-item demo coverage
4. animation / transitions
5. richer control styles
6. iPad side-by-side editor/preview layout

## Architecture constraint

Item presentation remains provider-driven and portable. The generic project,
workspace, and plugin core never executes arbitrary presentation closures,
model constructors, property getters, or user-supplied SwiftUI runtime code.
