# App Preview Roadmap — Locked

Status: **0.1.3 implementation in progress**

App Preview keeps three separate product paths:

`Run Code | Preview App | Build IPA`

## Completed before this batch

- generic PreviewProvider and Preview IR
- signed Native SwiftUI Preview Runtime
- modifier and stack-layout IR
- inline Live Preview with debounced refresh
- portable primitive `@State` definitions
- state-backed and interpolated Text

## Binding + interactive controls — current batch

Preview IR now has a portable `PreviewBindingReference`.

The built-in SwiftUI Preview Provider recognizes:

```swift
@State private var name = "Guest"
@State private var enabled = true

TextField("Name", text: $name)
Toggle("Enabled", isOn: $enabled)
```

The provider emits binding references by state name. It does not emit or expose
SwiftUI's native `Binding` type.

The signed Preview Runtime converts those references into native bindings backed
by `PreviewStateStore`:

```text
TextField / Toggle
        ↓
PreviewBindingReference
        ↓
PreviewStateStore
        ↓
Native SwiftUI Binding
        ↓
Interactive preview state
```

This makes the preview genuinely interactive: typing into a TextField or
changing a Toggle mutates runtime preview state, and state-backed/interpolated
Text can update from the same store without rebuilding or reinstalling an IPA.

Unknown binding targets produce Preview diagnostics instead of silently creating
new state.

## Next preview layers

1. `Picker` and selection bindings
2. Button actions with a constrained Preview Action IR
3. navigation destinations and sheets
4. animation/transitions
5. richer TextField/Toggle styles
6. iPad side-by-side editor/preview layout

## Architecture constraint

Native SwiftUI `Binding` remains inside the signed runtime. ProjectStore,
ProjectWorkspace, ProjectSession, Live Preview scheduling, and the generic
plugin/provider layer remain independent from SwiftUI-specific state machinery.
