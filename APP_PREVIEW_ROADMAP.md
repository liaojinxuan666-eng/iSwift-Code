# App Preview Roadmap — Locked

Status: **0.1.3 implementation in progress**

App Preview keeps three separate product paths:

`Run Code | Preview App | Build IPA`

## Completed before this batch

- generic PreviewProvider and portable Preview IR
- signed Native SwiftUI Preview Runtime
- modifier and stack-layout IR
- inline Live Preview with debounced refresh
- primitive `@State` model
- state-backed/interpolated Text
- TextField / Toggle bindings
- Picker + selection bindings
- constrained Button PreviewAction IR
- actionable Button runtime

## NavigationLink — current batch

The Preview IR now has a portable navigation node:

```text
NavigationStack
    ↓
NavigationLink(title, destination IR)
    ↓
Signed SwiftUI Preview Runtime
    ↓
Native NavigationLink push
```

Supported first form:

```swift
NavigationStack {
    NavigationLink("Details") {
        VStack {
            Text("Details")
        }
    }
}
```

The destination is parsed through the same safe PreviewProvider stack. It can
therefore contain the already-supported Text, stacks, modifiers, state-backed
Text, TextField, Toggle, Picker, and constrained actionable Buttons.

Primitive `@State` declarations from the source are made available while
parsing the destination so destination controls/actions can target the same
PreviewStateStore at runtime.

This batch intentionally does not change the default SwiftUI project template.
The core navigation path should pass CI first; the template/demo can be upgraded
after the navigation IR/runtime itself is proven.

## Current limitation

This first navigation lowering handles `NavigationLink("Title") { ... }`.
Nested NavigationLink lowering inside another destination and the alternative
`destination:` initializer syntax are reserved for a later navigation pass.

## Next preview layers

1. navigationTitle + template/demo integration
2. nested NavigationLink destinations
3. sheets / presentation state
4. animation/transitions
5. richer control styles
6. iPad side-by-side editor/preview layout

## Architecture constraint

Navigation source parsing stays inside the SwiftUI navigation provider. The
generic project/workspace/plugin core does not gain SwiftUI navigation types or
execute destination source directly.
