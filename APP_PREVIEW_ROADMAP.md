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

### Live Preview — current batch

The preview is now an inline workspace panel instead of a modal sheet.

While the preview panel is visible:

1. the user keeps the code editor available in the same workspace,
2. source edits schedule a debounced preview update,
3. rapid keystrokes cancel older pending updates,
4. only the latest edit takes a new workspace snapshot,
5. the snapshot still includes unsaved editor buffers,
6. the signed Preview Runtime replaces the visible preview without rebuilding or reinstalling an IPA.

Default debounce delay: **350 ms**.

The debounce lives in `PreviewSessionViewModel`, not in the SwiftUI Preview Provider. This keeps PreviewProvider implementations independent from editor timing policy.

## Next preview layers

1. spacing/alignment and richer modifier parsing
2. State / Binding preview state model
3. TextField / Toggle / Picker interactive controls
4. navigation destinations and sheets
5. animation/transitions
6. iPad side-by-side editor/preview layout

## Architecture constraint

Live Preview remains snapshot-driven. ProjectStore, ProjectWorkspace, and ProjectSession do not gain SwiftUI-specific behavior, and preview generation never requires saving the active file first.
