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
- built-in Sheet / Full Screen / Navigation demo

## Full-screen item presentation — current batch

App Preview now supports:

```swift
@State private var selectedItem: String? = nil

Button("Open") {
    selectedItem = "Details"
}
.fullScreenCover(item: $selectedItem) { item in
    VStack {
        Text(item)

        Button("Close") {
            selectedItem = nil
        }
    }
}
```

The source closure is parsed to portable Preview IR; arbitrary Swift is not
executed. Optional String / Bool / Number state uses the same typed optional
state foundation added for `.sheet(item:)`.

Pipeline:

```text
.fullScreenCover(item:) source
        ↓
SwiftUIFullScreenCoverItemPreviewProvider
        ↓
validate typed optional primitive @State
        ↓
portable PreviewModifier.fullScreenCover
        ↓
signed Preview Runtime
        ↓
native SwiftUI fullScreenCover(item:)
```

The existing portable `fullScreenCover` modifier is intentionally reused. The
runtime selects the native overload from the bound state kind:

```text
Bool state             → fullScreenCover(isPresented:)
Optional primitive     → fullScreenCover(item:)
```

Dismissal writes nil back through the portable optional binding, preserving the
same state ownership model used by `.sheet(item:)`.

## Current item limitation

Item-driven presentation currently accepts typed optional primitive state:

- `String?`
- `Bool?`
- `Int?` / `Double?` / `Float?`

Custom Identifiable item models are intentionally deferred to richer item-model
IR rather than being special-cased.

## Next preview layers

1. built-in item-presentation demo
2. richer Identifiable item-model IR
3. animation / transitions
4. richer control styles
5. iPad side-by-side editor/preview layout

## Architecture constraint

Item presentation remains provider-driven and portable. The generic project,
workspace, and plugin core never executes arbitrary presentation closures or
depends on user-supplied SwiftUI runtime code.
