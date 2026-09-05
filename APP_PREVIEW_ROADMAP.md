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

## Optional item-state foundation — completed

App Preview now preserves typed optional primitive state while the current value
is nil:

```swift
@State private var selectedItem: String? = nil
@State private var selectedFlag: Bool? = nil
@State private var selectedNumber: Int? = nil
```

Portable state values:

```text
optionalString(String?)
optionalBool(Bool?)
optionalNumber(Double?)
```

The constrained action layer also supports `clear`, so setting an optional item
to `nil` remains a portable state mutation.

## Sheet item presentation — current batch

The first item-driven presentation pass accepts:

```swift
@State private var selectedItem: String? = nil

Button("Open") {
    selectedItem = "Details"
}
.sheet(item: $selectedItem) { item in
    VStack {
        Text(item)

        Button("Close") {
            selectedItem = nil
        }
    }
}
```

Provider pipeline:

```text
.sheet(item:) source
        ↓
SwiftUISheetItemPreviewProvider
        ↓
validate typed optional primitive @State
        ↓
rebind closure item parameter to portable state
        ↓
existing PreviewModifier.sheet IR
        ↓
signed Preview Runtime
        ↓
native SwiftUI .sheet(item:) bridge
```

The runtime uses an internal Identifiable presentation token only as the native
SwiftUI bridge. User source closures are still not executed. The sheet content
reads the same `PreviewStateStore`, and native dismissal clears the optional
state back to nil.

Current content support includes direct item text (`Text(item)`), simple item
interpolation, the existing safe controls/actions, navigation, and nested
presentations.

This first pass remains intentionally limited to typed optional primitive state
initialized to nil. Rich Identifiable source models remain a later item-model IR
extension.

## Next preview layers

1. `.fullScreenCover(item:)`
2. richer item-model IR
3. item-presentation `onDismiss`
4. animation / transitions
5. richer control styles
6. iPad side-by-side editor/preview layout

## Architecture constraint

Presentation remains a portable, provider-driven layer. The generic
project/workspace/plugin core never executes arbitrary presentation closures or
depends directly on user-supplied SwiftUI presentation code.
