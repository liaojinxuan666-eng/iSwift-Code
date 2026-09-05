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

## Current Identifiable source subset

The top-level Live Preview provider now recognizes:

```swift
struct DetailItem: Identifiable {
    let id: Int
    let title: String
}

@State private var selectedItem: DetailItem? = nil
```

Supported stored member types:

- `String`
- `Bool`
- `Int`
- `Double`
- `Float`

`id` is required.

The provider does not execute the source model. It rewrites only the custom
optional state type to a parser-safe placeholder, runs the existing preview
provider stack, then restores the resulting state as portable
`PreviewOptionalIdentifiableItemState`.

This also allows `.sheet(item:)` and `.fullScreenCover(item:)` to be
structurally lowered for custom Identifiable state while the value is nil.

## Still pending

The following source still needs constructor/action lowering:

```swift
Button("Open") {
    selectedItem = DetailItem(
        id: 1,
        title: "Details"
    )
}
```

After that, runtime presentation can receive a real portable custom item.

## Next preview layers

1. lower constrained model initializer assignment into Identifiable item IR
2. runtime custom-item presentation bridge
3. `item.member` access inside presentation content
4. animation / transitions
5. richer control styles
6. iPad side-by-side editor/preview layout

## Architecture constraint

Item presentation remains provider-driven and portable. The generic project,
workspace, and plugin core never executes arbitrary presentation closures or
depends on user-supplied SwiftUI runtime code.
