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

## Built-in item presentation demo — current batch

The default SwiftUI Preview project now exercises both item-driven
presentation overloads with separate optional bindings:

```swift
@State private var selectedSheetItem: String? = nil
@State private var selectedFullScreenItem: String? = nil
```

Sheet item flow:

```swift
Button("Open Item Sheet") {
    selectedSheetItem = "Sheet Item"
}
.sheet(item: $selectedSheetItem) { item in
    VStack {
        Text(item)

        Button("Close Item Sheet") {
            selectedSheetItem = nil
        }
    }
}
```

Full-screen item flow:

```swift
Button("Open Item Full Screen") {
    selectedFullScreenItem = "Full Screen Item"
}
.fullScreenCover(
    item: $selectedFullScreenItem
) { item in
    VStack {
        Text(item)

        Button("Close Item Full Screen") {
            selectedFullScreenItem = nil
        }
    }
}
```

Separate bindings are intentional: opening one demo must not activate the other
presentation modifier.

All built-in template regression tests now parse through the current top-level
`SwiftUIFullScreenCoverItemPreviewProvider`, so future presentation syntax in
the template is validated by the same stack used by Live Preview.

## Current item limitation

Item-driven presentation still accepts typed optional primitive state only:

- `String?`
- `Bool?`
- `Int?` / `Double?` / `Float?`

## Next preview layers

1. richer Identifiable item-model IR
2. item member access inside presentation content
3. animation / transitions
4. richer control styles
5. iPad side-by-side editor/preview layout

## Architecture constraint

Item presentation remains provider-driven and portable. The generic project,
workspace, and plugin core never executes arbitrary presentation closures or
depends on user-supplied SwiftUI runtime code.
