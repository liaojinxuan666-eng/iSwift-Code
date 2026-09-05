# iSwift Code

iSwift Code is a local-first coding environment for iPhone and iPad. The project
is designed around a difficult baseline: useful development workflows should
work on a normal, non-jailbroken iOS device without making cloud compilation the
only way to run code.

## Version 0.1.2

0.1.2 expands iSwift Code from a single-file Swift runner into the foundation of
a project-aware, extensible development environment.

### Local execution

The current Instant Run backend remains a sandbox-safe compiler and virtual
machine written in Swift:

`source -> lexer -> parser -> AST -> bytecode -> virtual machine`

The Swift-compatible core currently supports:

- `let` and `var`
- assignment
- `Int`, `Double`, `String`, and `Bool` literals
- arithmetic, comparison, equality, and Boolean operators
- `if` / `else`
- `while`
- `break` / `continue`
- lexical block scopes and variable shadowing
- `print(...)`
- `//` comments
- line-and-column diagnostics
- a 100,000-instruction execution safety limit

This backend is intentionally not presented as Apple's full Swift compiler.

### Project system

0.1.2 adds a reusable project layer:

- canonical project-relative `WorkspacePath`
- multi-file `ProjectWorkspace`
- replaceable workspace storage backends
- persistent `ProjectStore`
- per-project `.iswift/project.json` metadata
- project snapshots for compiler/AI/build consumers
- entry-file selection
- transactional entry-file rename/delete metadata updates
- Project Session editor state
- per-file buffers and dirty tracking
- create, rename, delete, save, and switch files
- persistent multiple projects
- project browser
- project templates

The app now opens into a Projects screen instead of one hard-coded Scratch
workspace.

### Provider and plugin architecture

0.1.2 also introduces a provider-agnostic plugin foundation.

The plugin core defines:

- `PluginManifest`
- capability declarations
- permission declarations
- API-version validation
- lifecycle/registry management
- permission-checked Host Services
- built-in, WebAssembly, and remote-service execution modes

Typed provider contracts currently include:

- `CompilerProvider`
- `AIProvider`
- reserved `WasmPluginLoader` boundary

The existing sandbox compiler is connected through
`SandboxSwiftCompilerProvider`; it is an implementation of the generic compiler
contract, not a special case in the editor core.

Future Clang/LLVM, fuller Swift, AI coding services, and other tools should plug
into these contracts rather than adding provider-specific branches to the
project system.

### App Preview is locked for 0.1.3

The next major milestone is App Preview.

The product model is intentionally split into:

`Run Code | Preview App | Build IPA`

Preview will use a generic `PreviewProvider` and a signed host-controlled Preview
Runtime. It must not require arbitrary downloaded dylibs, unsigned native code,
or JIT simply to display a preview on a stock iOS device.

See `APP_PREVIEW_ROADMAP.md`.

## Current limitations

0.1.2 does not yet provide:

- Apple's full Swift compiler
- user-defined functions / `return` in the sandbox language
- arrays, dictionaries, optionals, structs, classes, enums, protocols, closures
- full Foundation or SwiftUI source compilation
- multi-file execution in `SandboxSwiftCompilerProvider`
- a production Clang/LLVM provider
- a production AI/Codex provider
- WebAssembly plugin execution
- plugin marketplace / install UI
- App Preview rendering
- native app building or IPA export

The project/workspace architecture is already multi-file even where the current
sandbox compiler provider is not.

## Build

The repository uses XcodeGen:

```sh
brew install xcodegen
xcodegen generate
open iSwiftCode.xcodeproj
```

Select the `iSwiftCode` scheme and run on an iOS 17 or newer device or
simulator.

GitHub Actions regenerates the project, builds the iOS target, and runs the test
suite on every push to `main`.

## Roadmap

1. **0.1.3 App Preview Foundation**
   - `PreviewProvider`
   - Preview IR
   - signed Preview Runtime
   - SwiftUI-compatible structural nodes
   - editor/preview switching on iPhone
   - side-by-side workflow on iPad

2. **Compiler expansion**
   - functions and `return`
   - richer values and collections
   - fuller Swift frontend/backend path
   - multi-file compiler providers
   - Clang/LLVM provider

3. **Extension ecosystem**
   - real Wasm plugin runtime
   - permission UI
   - persistent plugin state
   - AI provider implementations
   - editor/build/project plugins

4. **Native application pipeline**
   - SwiftUI app projects
   - resources and build metadata
   - deterministic native builds
   - signing
   - IPA export
