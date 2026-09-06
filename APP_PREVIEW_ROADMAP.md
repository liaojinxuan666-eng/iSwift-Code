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
- source-level validation diagnostics for unknown custom item members
- built-in Identifiable sheet/full-screen regression demo catalog

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

Unknown members now fail during Preview generation:

```swift
Text(item.notExist)
Text("Value: \(item.notExist)")
```

Example diagnostic:

```text
Identifiable preview model 'DetailItem' has no stored member 'notExist'.
Available members: id, title.
```

Validation happens before runtime member lookup, so invalid source no longer
silently renders an empty string.

The validator is source-only and portable. It never executes the source model,
property getters, presentation closures, or interpolation expressions.

## Built-in custom-item regression demos

`PreviewIdentifiableDemoCatalog` now keeps source fixtures for both:

- `.sheet(item:)`
- `.fullScreenCover(item:)`

Each successful fixture exercises the same path used by user files:

```text
Identifiable source model
→ typed optional @State
→ constructor Button action
→ portable item state
→ item presentation
→ direct item.member
→ interpolated item.member
→ clear back to nil
```

A deliberately invalid fixture also verifies that an unknown member produces a
Preview diagnostic before runtime rendering.

These fixtures are regression inputs only; they do not execute source SwiftUI
code directly.

## Existing paths remain unchanged

- primitive `Text(item)` item presentation
- direct custom `Text(item.member)`
- custom item-member interpolation
- ordinary `Text("\(state)")` preview interpolation
- primitive Button actions
- custom Identifiable constructor actions

## Next preview layers

1. animation / transitions
2. richer control styles
3. iPad side-by-side editor/preview layout

## Architecture constraint

Item presentation remains provider-driven and portable. The generic project,
workspace, and plugin core never executes arbitrary presentation closures,
model constructors, property getters, interpolation expressions, or
user-supplied SwiftUI runtime code.
