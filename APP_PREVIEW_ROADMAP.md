# App Preview Roadmap — Locked

Status: **0.1.3 implementation in progress**

App Preview remains a core iSwift Code feature with three separate product paths:

`Run Code | Preview App | Build IPA`

## Completed

### Preview foundation

- generic `PreviewProvider`
- `PluginCapability.preview`
- provider discovery through PluginRegistry
- structural Preview IR
- signed Native SwiftUI Preview Runtime
- SwiftUI Preview project template

### Modifier and layout IR

- padding / frame
- foreground/background
- font / corner radius
- VStack/HStack spacing
- VStack/HStack alignment
- ZStack alignment

### Live Preview

- inline workspace preview panel
- unsaved-buffer snapshots
- 350 ms debounced automatic refresh
- cancellation of stale refreshes
- manual refresh and close controls

### Preview State Model — current batch

The Preview IR can now carry primitive SwiftUI-style `@State` declarations:

- `String`
- `Bool`
- numeric values

Examples:

```swift
@State private var status = "Ready"
@State private var enabled = true
@State private var count = 0
```

The built-in SwiftUI Preview Provider extracts those declarations into portable
`PreviewStateDefinition` values. The provider does not expose SwiftUI's native
`State` object to the generic Preview IR.

The signed Preview Runtime owns a `PreviewStateStore` initialized from those
definitions.

State-backed text is also supported:

```swift
Text(status)
Text("Count: \(count)")
```

Simple identifier interpolation is resolved by the runtime. Existing literal
`Text("Hello")` behavior remains unchanged.

This state store is intentionally built before Binding/controls so the next
batch can attach `Binding`, `TextField`, and `Toggle` to one stable runtime
model instead of implementing control-local state.

## Next preview layers

1. portable `Binding` references
2. interactive `TextField`
3. interactive `Toggle`
4. `Picker`
5. navigation destinations and sheets
6. animation/transitions
7. iPad side-by-side editor/preview layout

## Architecture constraint

`@State` source parsing remains inside the SwiftUI Preview Provider. Mutable
preview values live in the signed Preview Runtime. ProjectStore,
ProjectWorkspace, ProjectSession, Live Preview scheduling, and the generic
Plugin core remain unaware of SwiftUI's native state system.
