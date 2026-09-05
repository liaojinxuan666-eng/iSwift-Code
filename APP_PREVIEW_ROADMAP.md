# App Preview Roadmap — Locked

Status: **0.1.3 implementation in progress**

App Preview remains a core iSwift Code feature with three separate product paths:

`Run Code | Preview App | Build IPA`

## Completed in 0.1.3 foundation

- generic `PreviewProvider`
- `PluginCapability.preview`
- provider discovery through PluginRegistry
- structural Preview IR
- signed Native SwiftUI Preview Runtime
- workspace preview from unsaved project snapshots
- SwiftUI Preview project template

Structural nodes currently include:

- Text
- Button
- SF Symbol Image(systemName:)
- Spacer
- VStack / HStack / ZStack
- ScrollView
- List
- NavigationStack

## Modifier IR — current batch

Preview IR now preserves these SwiftUI-style modifiers:

- `.padding()` / `.padding(number)`
- `.frame(width:height:)`
- `.frame(maxWidth:maxHeight:)`, including `.infinity`
- `.foregroundStyle(color)`
- `.background(color)`
- `.font(style)`
- `.cornerRadius(number)`

Supported named colors and semantic colors are represented as portable Preview IR values rather than embedding SwiftUI `Color` objects in provider output.

The signed Preview Runtime maps those portable values onto native SwiftUI when rendering.

## Next preview layers

1. automatic/debounced refresh while editing
2. richer modifier parsing and alignment/spacing
3. State / Binding
4. TextField / Toggle / Picker
5. sheets/navigation/animation
6. iPad side-by-side editor/preview layout

## Architecture constraint

SwiftUI parsing and SwiftUI rendering remain inside the SwiftUI Preview Provider / Preview Runtime implementation. ProjectStore, ProjectWorkspace, ProjectSession, and the generic provider/plugin core remain provider-agnostic.
