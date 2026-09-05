# App Preview Roadmap — Locked

Status: **0.1.3 implementation in progress**

App Preview keeps three separate product paths:

`Run Code | Preview App | Build IPA`

## Completed before this batch

- generic PreviewProvider and Preview IR
- signed Native SwiftUI Preview Runtime
- modifier and stack-layout IR
- inline Live Preview with debounced refresh
- portable primitive `@State` definitions
- state-backed and interpolated Text
- binding-backed `TextField` and `Toggle`
- `Picker` and selection bindings

## Button actions — current batch

App Preview now has the foundation for a constrained `PreviewAction` IR.

The action layer deliberately does **not** execute arbitrary Swift closures.
Providers will lower a small, portable set of state mutations into:

- `set(stateName:value:)`
- `add(stateName:amount:)`
- `toggle(stateName:)`

Multiple mutations are carried by a `PreviewActionProgram`.

`PreviewActionValidator` checks every target against the preview's existing
`@State` definitions before execution. Unknown states and incompatible action
types are rejected instead of silently creating or coercing state.

`PreviewStateStore.perform(_:)` performs a complete compatibility preflight
before applying the program, so an invalid program cannot partially mutate
preview state.

The next Button batch will connect source such as:

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

to this action IR and then wire the signed Preview Runtime button tap to
`PreviewStateStore`.

## Next preview layers

1. Button source lowering + runtime action execution
2. navigation destinations and sheets
3. animation/transitions
4. richer TextField/Toggle/Picker styles
5. iPad side-by-side editor/preview layout

## Architecture constraint

Native SwiftUI `Binding` and executable UI behavior remain inside the signed
runtime. ProjectStore, ProjectWorkspace, ProjectSession, Live Preview
scheduling, and the generic plugin/provider layer remain independent from
SwiftUI-specific state machinery.

Button source closures are never executed directly by App Preview. Only
validated, explicitly supported `PreviewAction` operations may reach the
runtime state store.
