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
- direct `Text(item.member)` lowering
- item-member string interpolation in Text

## Current custom item Text support

Direct member access:

```swift
Text(item.title)
Text(item.id)
```

Member interpolation:

```swift
Text("Title: \(item.title)")
Text("ID: \(item.id)")
Text("\(item.id): \(item.title)")
```

The provider replaces source interpolation with portable markers before the
existing parser stack runs. The resulting Preview IR stores only:

```text
template
+ stateName
+ memberName
```

At runtime, ordinary preview-state interpolation is resolved first, then each
portable item-member marker is replaced from `PreviewIdentifiableItem`.

No source property getter or interpolation expression is executed.

The same interpolation path works in both `.sheet(item:)` and
`.fullScreenCover(item:)`.

## Existing paths remain unchanged

- primitive `Text(item)` item presentation
- direct custom `Text(item.member)`
- ordinary `Text("\(state)")` preview interpolation
- primitive Button actions
- custom Identifiable constructor actions

## Next preview layers

1. validation diagnostics for unknown custom members
2. richer custom-item built-in demo coverage
3. animation / transitions
4. richer control styles
5. iPad side-by-side editor/preview layout

## Architecture constraint

Item presentation remains provider-driven and portable. The generic project,
workspace, and plugin core never executes arbitrary presentation closures,
model constructors, property getters, interpolation expressions, or
user-supplied SwiftUI runtime code.
