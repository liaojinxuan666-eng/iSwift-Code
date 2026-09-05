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

### Modifier IR

- `.padding()` / `.padding(number)`
- `.frame(width:height:)`
- `.frame(maxWidth:maxHeight:)`, including `.infinity`
- `.foregroundStyle(color)`
- `.background(color)`
- `.font(style)`
- `.cornerRadius(number)`

### Live Preview

- inline workspace preview panel
- unsaved-buffer snapshots
- 350 ms debounced automatic refresh
- cancellation of stale refreshes
- manual refresh and close controls

### Stack layout IR — current batch

SwiftUI stack initializer layout is now preserved instead of being discarded.

Supported:

- `VStack(alignment: .leading/.center/.trailing, spacing: number)`
- `HStack(alignment: .top/.center/.bottom/.firstTextBaseline/.lastTextBaseline, spacing: number)`
- `ZStack(alignment: .center/.leading/.trailing/.top/.bottom/.topLeading/.topTrailing/.bottomLeading/.bottomTrailing)`

These values remain portable Preview IR values. The signed SwiftUI runtime maps
them to native `HorizontalAlignment`, `VerticalAlignment`, and `Alignment`
values only at render time.

## Next preview layers

1. Preview state model for `@State`
2. `Binding`
3. interactive `TextField`, `Toggle`, and `Picker`
4. navigation destinations and sheets
5. animation/transitions
6. iPad side-by-side editor/preview layout

## Architecture constraint

Stack layout parsing stays inside the SwiftUI Preview Provider. ProjectStore,
ProjectWorkspace, ProjectSession, Live Preview scheduling, and the generic plugin
core remain unaware of SwiftUI-specific alignment types.
