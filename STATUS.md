# iSwift Code 0.1.2 status

## Release state

0.1.2 is the current stable development baseline.

The 0.1.2 development sequence has passed the repository's GitHub Actions gate:
XcodeGen project generation, iOS build, and XCTest execution are expected to
remain green before the next milestone is expanded.

## Implemented

### Sandbox language/runtime

- local lexer/parser/AST pipeline
- bytecode compiler and virtual machine
- `let` / `var`
- assignment
- scalar literals
- arithmetic/comparison/equality/Boolean operators
- `if` / `else`
- `while`
- `break` / `continue`
- lexical scopes
- variable shadowing
- scope unwinding
- console output
- source-location diagnostics
- instruction safety limit

### Provider/plugin foundation

- generic `PluginManifest`
- plugin capabilities
- plugin permissions
- API compatibility checks
- plugin lifecycle and registry
- built-in / Wasm / remote-service execution modes
- typed `CompilerProvider`
- typed `AIProvider`
- reserved `WasmPluginLoader`
- permission-checked Host Services
- workspace/network/credential/clipboard/user-file/build-artifact/external-URL
  host boundaries
- `SandboxSwiftCompilerProvider` integrated through the provider layer
- provider discovery through the registry

### Project foundation

- validated `WorkspacePath`
- `ProjectDescriptor`
- `ProjectWorkspaceStorage`
- in-memory storage
- directory-backed storage
- `ProjectWorkspace`
- immutable project snapshots
- workspace-to-CompilerProvider bridge
- workspace-to-AIProvider snapshot bridge
- plugin workspace backend
- persistent `ProjectStore`
- hidden `.iswift/project.json`
- entry-file mutation and persistence
- rollback protection for entry-file rename/delete metadata updates

### Project session/editor

- multi-file file list
- active-file switching
- per-file text buffers
- dirty-file tracking
- save active / save all
- create / rename / delete files
- set/rename/delete entry file
- compiler run from a workspace snapshot including unsaved buffers
- persistent scratch project

### Multiple projects

- Projects screen at app launch
- list persistent projects
- open projects
- create projects
- delete projects
- project templates
- Swift Console template
- Empty Project template
- unique project identifiers for duplicate display names

## Architecture constraints locked in 0.1.2

- project core remains provider-agnostic
- plugin core remains toolchain-agnostic
- Clang, Codex-like services, and Sandbox Swift are implementations, not core
  special cases
- plugins do not receive unrestricted app internals
- plugin Host Services enforce declared permissions
- normal non-jailbroken iOS remains the primary compatibility baseline
- arbitrary downloaded native dylibs are not the stock-iOS plugin model

## Current limitations

Still not implemented:

- full Apple Swift language/compiler
- sandbox-language functions / `return`
- arrays/dictionaries/optionals
- SwiftUI source compilation
- multi-file execution in the current Sandbox Swift provider
- production Clang/LLVM provider
- production AI provider
- Wasm execution runtime
- plugin install/management UI
- App Preview
- native build/sign/IPA export

## Next engineering gate: 0.1.3 App Preview

`APP_PREVIEW_ROADMAP.md` is locked.

The preview architecture will add:

`ProjectWorkspace -> PreviewProvider -> Preview IR -> Preview Runtime`

The first structural Preview surface targets:

- Text
- Button
- Image
- VStack / HStack / ZStack
- Spacer
- ScrollView
- List
- NavigationStack
- basic style modifiers

State, bindings, controls, navigation, sheets, and animation follow after the
structural renderer is stable.

App Preview must remain separate from native IPA building and must not require a
new IPA build/sign/install for each source edit.
