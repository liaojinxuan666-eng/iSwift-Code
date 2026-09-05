# iSwift Code

iSwift Code is a local-first Swift coding environment for iPhone and iPad. The
project deliberately starts with the hardest constraint: code must compile and
run on a normal, non-jailbroken iOS device without a cloud compiler.

## Version 0.1.0

The first compiler backend is a small sandbox-safe compiler written in Swift.
It performs a real pipeline:

`source -> lexer -> parser -> AST -> bytecode -> virtual machine`

It currently supports this Swift-compatible core:

- `let` and `var`
- assignment
- `Int`, `Double`, `String`, and `Bool` literals
- arithmetic, comparison, equality, and Boolean operators
- `if` / `else`
- `print(...)`
- `//` comments
- line-and-column diagnostics

This is not yet the full Apple Swift compiler. It is the executable foundation
that proves local compilation works within the standard iOS sandbox. The
`LocalCompilerBackend` protocol keeps the editor independent from the compiler
implementation so a fuller Swift/Wasm backend can replace it later.

## Build

The repository uses XcodeGen so the project file is reproducible:

```sh
brew install xcodegen
xcodegen generate
open iSwiftCode.xcodeproj
```

Select the `iSwiftCode` scheme and run on an iOS 17 or newer device/simulator.
The included GitHub Actions workflow builds the app and runs compiler tests on
a macOS runner.

## Locked roadmap

1. **Local Run** — expand the sandbox compiler and replace the basic editor with
   a project-aware editor.
2. **Fuller Swift** — integrate the official Swift parser and investigate a
   Swift 6.2 WebAssembly toolchain that can remain inside the iOS sandbox.
3. **App projects** — add SwiftUI templates, resources, package metadata, and
   deterministic builds.
4. **IPA export** — produce an app bundle, sign it with user-provided signing
   material, package `Payload/*.app`, and export an IPA for an external installer.

Native code produced by an editor cannot simply be executed inside the editor's
own stock-iOS process. The instant Run path therefore stays sandboxed, while the
later native iOS build path exports a signed IPA.
