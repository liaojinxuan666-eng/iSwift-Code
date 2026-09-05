# iSwift Code 0.1.1 status

## Release state

0.1.1 is the current stable development baseline.

The repository has a green GitHub Actions pipeline that:

- checks out the repository
- installs XcodeGen
- generates `iSwiftCode.xcodeproj`
- selects an available iOS Simulator
- builds the application target
- runs the compiler-core XCTest suite

This CI gate is now required before expanding the language surface.

## Implemented

- SwiftUI editor workspace for iPhone and iPad
- fully local, sandbox-safe compiler backend
- lexer with source locations and diagnostics
- recursive-descent parser and abstract syntax tree
- bytecode compiler with conditional and unconditional jumps
- stack virtual machine with a 100,000-instruction safety limit
- lexical block scopes
- variable shadowing
- `while` loops
- `break` and `continue`
- correct scope unwinding when leaving loops
- console output and inline error list
- XCTest coverage for:
  - arithmetic and variables
  - `if` / `else`
  - immutable `let` values
  - syntax locations
  - comments and strings
  - `while`
  - block scope and shadowing
  - block-local lifetime
  - `break`
  - `continue`
  - nested-scope loop exits
  - invalid loop-control statements
- reproducible XcodeGen project
- GitHub Actions build and test workflow

## Current language boundary

Version 0.1.1 intentionally implements a Swift-compatible executable core
rather than claiming to bundle Apple's full Swift compiler.

Not implemented yet:

- user-defined functions and `return`
- arrays and dictionaries
- optionals
- structs, classes, enums, and protocols
- closures
- string interpolation
- Foundation APIs
- SwiftUI compilation
- Swift Package dependencies
- multiple-file project compilation
- native iOS app building and IPA export

## Next engineering gate

The next compiler milestone should add function declarations, calls, parameters,
and `return` without breaking the 0.1.1 regression suite.

In parallel, the editor architecture can begin moving toward a project-aware
workspace so later SwiftUI projects, resources, package metadata, and extension
capabilities do not have to be retrofitted onto a single-file editor.

The native IPA pipeline remains a separate backend. Instant Run stays inside
the sandbox VM; native SwiftUI projects will later be compiled, signed, and
exported as installable IPA files instead of being injected into the editor
process.
