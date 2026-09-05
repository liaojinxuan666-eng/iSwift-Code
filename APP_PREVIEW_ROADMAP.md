# App Preview Roadmap — Locked

Status: **0.1.3 implementation in progress**

App Preview keeps three separate product paths:

`Run Code | Preview App | Build IPA`

## Completed

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
- `.fullScreenCover(isPresented:)`
- constrained `.fullScreenCover(... onDismiss:)`
- built-in Sheet / Full Screen / Navigation demo

## Full-screen onDismiss — completed

App Preview supports the safe form:

```swift
@State private var showingFullScreen = false
@State private var status = "Ready"

Button("Open Full Screen") {
    showingFullScreen = true
}
.fullScreenCover(
    isPresented: $showingFullScreen,
    onDismiss: {
        status = "Full Screen Closed"
    }
) {
    Button("Close Full Screen") {
        showingFullScreen = false
    }
}
```

The source dismissal closure is not executed as arbitrary Swift. It is lowered
to `PreviewActionProgram`, validated against preview-state definitions, then the
signed runtime applies the portable actions after native full-screen dismissal.

Supported dismissal mutations currently include:

```text
state = literal
number += literal
number -= literal
bool.toggle()
```

Unknown state references, incompatible state kinds, and unsupported statements
produce diagnostics before the runtime receives the presentation IR.

Portable IR:

```text
PreviewModifier.fullScreenCoverWithOnDismiss
├─ isPresented: PreviewBindingReference
├─ onDismiss: PreviewActionProgram
└─ content: PreviewNode
```

The built-in SwiftUI Preview template now exercises this path directly. Closing
the default Full Screen demo changes the shared `status` state to
`"Full Screen Closed"`.

## Next preview layers

1. `.sheet(item:)`
2. `.fullScreenCover(item:)`
3. animation / transitions
4. richer control styles
5. iPad side-by-side editor/preview layout

## Architecture constraint

Presentation remains a portable, provider-driven layer. The generic
project/workspace/plugin core never executes arbitrary presentation closures or
depends directly on user-supplied SwiftUI presentation code.
