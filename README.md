# iSwift Code

iSwift Code is a local-first Swift coding environment for iPhone and iPad. The
project deliberately starts with the hardest constraint: code must compile and
run on a normal, non-jailbroken iOS device without requiring a cloud compiler.

## Version 0.1.1

The current Instant Run backend is a sandbox-safe compiler and virtual machine
written in Swift. It performs a real local pipeline:

`source -> lexer -> parser -> AST -> bytecode -> virtual machine`

The Swift-compatible core currently supports:

- `let` and `var`
- assignment
- `Int`, `Double`, `String`, and `Bool` literals
- arithmetic, comparison, equality, and Boolean operators
- `if` / `else`
- `while`
- `break` / `continue`
- lexical block scopes with variable shadowing
- `print(...)`
- `//` comments
- line-and-column diagnostics
- a 100,000-instruction execution safety limit

Version 0.1.1 also has automated macOS/Xcode CI. Every push to `main` generates
the Xcode project with XcodeGen, builds the iOS target, and runs the compiler
core XCTest suite on an iOS Simulator.

This is not yet the full Apple Swift compiler. The current backend exists to
prove that useful Swift-like code can be parsed, compiled, and executed locally
inside the standard iOS sandbox. The `LocalCompilerBackend` abstraction keeps
the editor independent from a specific compiler implementation so a fuller
Swift/Wasm backend can be integrated later without rebuilding the entire app.

## Build

The repository uses XcodeGen so the Xcode project is reproducible:

```sh
brew install xcodegen
xcodegen generate
open iSwiftCode.xcodeproj
```

Select the `iSwiftCode` scheme and run on an iOS 17 or newer device or
simulator.

## Roadmap

1. **Local Run** — continue expanding the sandbox compiler and make the editor
   project-aware.
2. **Language core** — add functions, returns, richer values, collections, and
   stronger diagnostics while keeping regression tests green.
3. **Fuller Swift** — integrate the official Swift parser where practical and
   investigate a Swift/WebAssembly backend compatible with the iOS sandbox.
4. **App projects** — add multiple Swift files, SwiftUI templates, resources,
   package metadata, and deterministic builds.
5. **IPA export** — produce an app bundle, sign it with user-provided signing
   material, package `Payload/*.app`, and export an IPA for an external
   installer.

Native code produced by an editor cannot simply be injected into the editor's
own stock-iOS process. Instant Run therefore remains sandboxed, while the later
native iOS build path will export a separately signed app/IPA.
