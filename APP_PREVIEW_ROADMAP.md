# App Preview Roadmap — Locked

Status: **0.1.3 implementation in progress**

App Preview keeps three separate product paths:

`Run Code | Preview App | Build IPA`

## Completed before this batch

- portable Preview IR and signed native runtime
- Live Preview
- primitive `@State`
- TextField / Toggle / Picker bindings
- constrained Button action runtime
- NavigationStack / NavigationLink
- labeled + nested NavigationLink forms
- navigationTitle
- `.sheet(isPresented:)`
- constrained `.sheet(... onDismiss:)`
- built-in multi-page + sheet demo

## Full-screen presentation — current batch

App Preview now lowers:

```swift
@State private var showingCover = false

Button("Open") {
    showingCover = true
}
.fullScreenCover(isPresented: $showingCover) {
    VStack {
        Text("Full Screen")

        Button("Close") {
            showingCover = false
        }
    }
}
```

into portable presentation IR:

```text
PreviewModifier.fullScreenCover
├─ isPresented: PreviewBindingReference
└─ content: PreviewNode
```

Pipeline:

```text
.fullScreenCover source
        ↓
SwiftUIFullScreenCoverPreviewProvider
        ↓
validate Bool @State
        ↓
portable PreviewModifier.fullScreenCover
        ↓
signed Preview Runtime
        ↓
native SwiftUI fullScreenCover
```

Full-screen content is parsed through the same safe provider stack and shares
`PreviewStateStore`. It can contain current controls, actions, navigation,
sheets, and another supported full-screen cover.

Unknown state references and non-Bool bindings produce diagnostics before the
runtime receives IR.

## Current limitation

This first pass supports exactly:

```swift
.fullScreenCover(isPresented: $state) { ... }
```

`onDismiss:` for fullScreenCover and item-based presentation remain later
presentation passes.

## Next preview layers

1. default template full-screen demo
2. `.fullScreenCover(... onDismiss:)`
3. `.sheet(item:)`
4. animation / transitions
5. richer control styles
6. iPad side-by-side editor/preview layout

## Architecture constraint

Full-screen presentation is another portable modifier layered above the current
Sheet / Navigation / Interactive providers. The generic project/workspace/plugin
core never executes arbitrary presentation closures or depends directly on
SwiftUI presentation APIs.
