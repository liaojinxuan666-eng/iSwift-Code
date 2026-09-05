# App Preview Roadmap — Locked

Status: **locked for 0.1.3**

App Preview is a core iSwift Code feature, not a one-off SwiftUI demo and not an
editor-specific hack.

## Product modes

The long-term workspace exposes three distinct actions:

```text
Run Code
Preview App
Build IPA
```

They are separate execution paths.

### Run Code

Execute code through the selected `CompilerProvider` / local runtime.

### Preview App

Render the project's application UI through a `PreviewProvider` and a
host-controlled preview runtime.

### Build IPA

Build and sign a separate native application bundle through the future native
build/export backend.

## Stock-iOS rule

App Preview must work on normal non-jailbroken iOS devices.

The core design must not depend on downloading an arbitrary dylib, injecting
unsigned native machine code, or requiring JIT merely to display a preview.

The intended pipeline is:

```text
Project Workspace
      ↓
PreviewProvider
      ↓
Preview IR / UI Representation
      ↓
Signed Preview Runtime
      ↓
Native SwiftUI / UIKit rendering
```

The preview runtime ships as part of iSwift Code and exposes controlled,
pre-signed native UI capabilities.

## Architecture

Preview joins the existing provider architecture:

```text
ProjectWorkspace
    ├─ CompilerProvider
    ├─ AIProvider
    ├─ PreviewProvider       ← 0.1.3
    └─ BuildProvider         ← later
```

No SwiftUI-specific branch may be added to ProjectStore, ProjectWorkspace,
ProjectSession, PluginRegistry, or the editor core.

## 0.1.3 first preview surface

Initial SwiftUI-compatible preview nodes should cover:

- Text
- Button
- Image
- VStack
- HStack
- ZStack
- Spacer
- ScrollView
- List
- NavigationStack
- foreground/background colors
- font
- padding
- frame
- background
- corner radius

State and interaction follow after the structural renderer is stable:

- `@State`
- Binding
- TextField
- Toggle
- Picker
- Sheet
- navigation
- animation

## Device layouts

Phone:

- Editor / Preview switch
- optional vertical split where practical

iPad:

- editor and preview side-by-side
- resizable preview surface later

## Refresh model

The target behavior is:

```text
edit source
   ↓
update project snapshot
   ↓
rebuild preview representation
   ↓
refresh preview
```

A preview refresh must not require exporting/signing/installing a new IPA for
every source edit.

## Plugin relationship

Preview providers may eventually be extensible, but the preview contract must
remain provider-agnostic.

Possible future implementations include:

- SwiftUI Preview Provider
- UIKit Preview Provider
- Web Preview Provider
- game/custom renderer preview providers

The generic Preview API must not be defined around any one of them.
