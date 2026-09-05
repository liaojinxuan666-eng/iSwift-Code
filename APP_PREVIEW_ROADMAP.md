# App Preview Roadmap — Locked

Status: **0.1.3 implementation in progress**

App Preview keeps three separate product paths:

`Run Code | Preview App | Build IPA`

## Completed

- generic PreviewProvider and portable Preview IR
- signed Native SwiftUI Preview Runtime
- modifier and stack-layout IR
- inline Live Preview with debounced refresh
- primitive `@State` model
- state-backed and interpolated Text
- Binding-backed TextField and Toggle
- Picker + selection bindings
- constrained PreviewAction IR

## Actionable Button runtime — current batch

App Preview now lowers a deliberately small Swift Button mutation subset into
`PreviewActionProgram` and executes it through `PreviewStateStore`.

Supported source forms:

```swift
count += 1
count -= 1
enabled.toggle()
status = "Done"
enabled = true
count = 10
```

Example:

```swift
@State private var count = 0
@State private var enabled = false

Button("Add") {
    count += 1
}

Button("Toggle") {
    enabled.toggle()
}
```

Pipeline:

```text
Swift Button closure
        ↓
Button Action Source Rewriter
        ↓
PreviewActionProgram
        ↓
PreviewActionValidator
        ↓
PreviewNode.actionButton
        ↓
Signed Preview Runtime
        ↓
PreviewStateStore.perform(...)
        ↓
State-backed UI updates immediately
```

Arbitrary Swift closures are never executed by App Preview. Unsupported
statements produce a diagnostic. Unknown state names and incompatible mutation
types are rejected before the program can mutate runtime state.

Legacy empty Buttons continue to preview as non-actionable buttons, preserving
existing behavior and tests.

## Next preview layers

1. navigation destinations + NavigationLink
2. sheets / presentation state
3. animation and transitions
4. richer control styles
5. iPad side-by-side editor/preview layout

## Architecture constraint

Button execution remains constrained to portable PreviewAction operations.
ProjectStore, ProjectWorkspace, ProjectSession, Live Preview scheduling, and the
generic plugin core never execute arbitrary source code or Swift closures.
