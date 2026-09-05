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

## Current custom item flow

The top-level Live Preview stack now supports the first complete portable custom
item presentation path:

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
    Text(item)
}
```

Lowering path:

```text
DetailItem(id:title:)
        ↓
PreviewIdentifiableItem
        ↓
PreviewAction.set
        ↓
PreviewOptionalIdentifiableItemState
        ↓
native item-driven Sheet / Full Screen
```

The source model and constructor are never executed.

## Constructor subset

Supported stored member literal types:

- `String`
- `Bool`
- `Int`
- `Double`
- `Float`

Every declared supported member must be supplied by the constrained constructor.
Unknown members, duplicate members, missing members, wrong literal types, and
assigning the wrong model type to a custom optional state produce diagnostics.

Existing primitive Button actions and primitive item presentation continue
through the established provider path.

## Runtime identity

Custom Identifiable presentation identity now derives from:

```text
state name + model type + portable item id
```

Primitive item identity behavior is unchanged.

## Next preview layers

1. `item.member` access inside presentation content
2. member interpolation such as `Text("\(item.title)")`
3. richer custom-item demo coverage
4. animation / transitions
5. richer control styles
6. iPad side-by-side editor/preview layout

## Architecture constraint

Item presentation remains provider-driven and portable. The generic project,
workspace, and plugin core never executes arbitrary presentation closures,
model constructors, or user-supplied SwiftUI runtime code.
