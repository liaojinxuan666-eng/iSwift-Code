# iSwift Code 0.1.0 status

## Implemented

- SwiftUI editor workspace for iPhone and iPad
- fully local, sandbox-safe compiler backend
- lexer with source locations and diagnostics
- recursive-descent parser and abstract syntax tree
- bytecode compiler with conditional jumps
- stack virtual machine with a 100,000-instruction safety limit
- console output and inline error list
- XCTest coverage for arithmetic, variables, conditionals, comments, strings,
  immutable values, and syntax locations
- reproducible XcodeGen project and GitHub Actions build

## Current language boundary

Version 0.1.0 intentionally implements a Swift-compatible core rather than
claiming to bundle Apple's full Swift compiler. Functions, types, arrays,
optionals, loops, Foundation, SwiftUI compilation, package dependencies, and
string interpolation are not implemented yet.

## Next engineering gate

Upload this source tree to a Git repository and let the included workflow run
on a macOS/Xcode runner. The first gate is green compiler-core tests and a
launching iOS simulator build. Only then should the language surface expand.

The later IPA pipeline will be a separate backend. Instant Run remains inside
the sandbox VM; native SwiftUI projects will be compiled, signed, and exported
as installable IPA files instead of being injected into the editor process.
