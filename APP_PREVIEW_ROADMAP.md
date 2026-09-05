# App Preview Roadmap — Locked

Status: **0.1.3 implementation started**

App Preview is a core iSwift Code feature, not a one-off SwiftUI demo and not an editor-specific hack.

## Locked product modes

`Run Code | Preview App | Build IPA`

These remain separate execution paths.

## Stock-iOS rule

Preview works through signed code already shipped with iSwift Code:

`Project Workspace -> PreviewProvider -> Preview IR -> Signed Preview Runtime -> Native SwiftUI/UIKit`

It must not require arbitrary downloaded dylibs, unsigned native code, or JIT merely to render the preview.

## 0.1.3 first implementation

The first PreviewProvider contract and Preview IR are now introduced.

The built-in SwiftUI Preview Provider currently recognizes a structural subset:

- Text
- Button
- SF Symbol Image(systemName:)
- Spacer
- VStack
- HStack
- ZStack
- ScrollView
- List
- NavigationStack

The signed Preview Runtime renders those nodes using native SwiftUI views already compiled into iSwift Code.

The workspace can generate the preview from a snapshot that includes unsaved editor buffers, so preview does not require saving or rebuilding/installing an IPA first.

## Next preview layers

1. modifier IR: padding, frame, foreground/background, font, corner radius
2. better SwiftUI parsing/diagnostics
3. automatic refresh while editing
4. state and controls: State, Binding, TextField, Toggle, Picker
5. sheets/navigation/animation
6. iPad side-by-side editor/preview layout

## Architecture constraint

No SwiftUI-specific branch may be added to ProjectStore, ProjectWorkspace, ProjectSession, or the generic Plugin core. SwiftUI is one PreviewProvider implementation.
