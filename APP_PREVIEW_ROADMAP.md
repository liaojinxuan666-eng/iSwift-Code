# App Preview Roadmap — Locked

Status: **0.1.3 implementation in progress**

App Preview keeps three separate product paths:

`Run Code | Preview App | Build IPA`

## Completed

- portable Preview IR and signed native runtime
- modifier + stack layout IR
- Live Preview with unsaved-buffer refresh
- primitive `@State`
- TextField / Toggle / Picker bindings
- constrained Button action runtime
- NavigationStack + NavigationLink
- navigationTitle
- multi-page built-in Preview template

## Nested NavigationLink — current batch

Navigation destinations are now parsed recursively through the navigation-aware
provider rather than stopping at the lower-level interactive provider.

That allows:

```swift
NavigationStack {
    NavigationLink("First") {
        VStack {
            Text("First page")

            NavigationLink("Second") {
                Text("Second page")
            }
        }
    }
}
```

and deeper supported trees.

Nested destinations keep using the same portable Preview IR and the same signed
runtime. They can also contain already-supported state-backed Text, TextField,
Toggle, Picker, and constrained actionable Buttons.

Primitive source `@State` declarations are carried into each destination parse,
so a deeply nested page can reference the same runtime PreviewStateStore.

A nesting-depth guard is included to prevent pathological recursive preview
input from recursing indefinitely.

## Next preview layers

1. alternative NavigationLink initializer forms
2. sheets / presentation state
3. animation and transitions
4. richer control styles
5. iPad side-by-side editor/preview layout

## Architecture constraint

Nested destinations are still parsed, lowered, and validated. They are never
executed as arbitrary Swift source. ProjectStore, ProjectWorkspace,
ProjectSession, and the generic plugin core remain independent from SwiftUI
navigation implementation details.
