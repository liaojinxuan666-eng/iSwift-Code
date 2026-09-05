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
- labeled and nested NavigationLink forms
- navigationTitle

## Sheet presentation — current batch

The Preview IR now carries a portable presentation modifier:

```text
PreviewModifier.sheet
├─ isPresented: PreviewBindingReference
└─ content: PreviewNode
```

Supported first form:

```swift
@State private var showingDetails = false

Button("Show") {
    showingDetails = true
}
.sheet(isPresented: $showingDetails) {
    VStack {
        Text("Details")

        Button("Close") {
            showingDetails = false
        }
    }
}
```

Pipeline:

```text
.sheet(isPresented: $state) source
        ↓
SwiftUISheetPreviewProvider
        ↓
validated Bool state binding
        ↓
portable PreviewModifier.sheet
        ↓
signed Preview Runtime
        ↓
native SwiftUI sheet
```

Sheet content is parsed through the same safe preview stack and shares the same
PreviewStateStore at runtime. It can therefore use state-backed Text, controls,
Picker, actionable Buttons, navigation, and even another supported sheet.

Unknown state references and non-Bool `isPresented` bindings produce preview
diagnostics.

## Current limitation

This first presentation pass supports exactly:

```swift
.sheet(isPresented: $state) { ... }
```

`onDismiss:`, `.sheet(item:)`, custom detents, popovers, and fullScreenCover are
reserved for later presentation passes.

## Next preview layers

1. default template sheet demo integration
2. `.sheet(onDismiss:)` support
3. `.fullScreenCover(isPresented:)`
4. animation / transitions
5. richer control styles
6. iPad side-by-side editor/preview layout

## Architecture constraint

Presentation source is lowered to portable IR and validated state references.
The generic project/workspace/plugin core never executes arbitrary presentation
closures or depends directly on SwiftUI sheet APIs.
