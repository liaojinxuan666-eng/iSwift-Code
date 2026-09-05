# App Preview Roadmap — Locked

Status: **0.1.3 implementation in progress**

App Preview keeps three separate product paths:

`Run Code | Preview App | Build IPA`

## Completed before this batch

- portable Preview IR and signed native runtime
- modifier + stack layout IR
- Live Preview with unsaved-buffer refresh
- primitive @State model
- TextField / Toggle / Picker bindings
- constrained Button action runtime
- NavigationStack + NavigationLink push navigation

## Navigation titles + multi-page template — current batch

The generic modifier IR now carries:

```swift
.navigationTitle("Title")
```

The SwiftUI Preview Provider parses the title as a portable string modifier and
the signed runtime maps it to native SwiftUI `navigationTitle` only at render
time.

The built-in SwiftUI Preview template is now a real multi-page demo. Its first
screen contains the existing state/binding/action examples and a
`NavigationLink("Open Details")`. The destination displays the same preview
state and has its own navigation title.

Example:

```swift
NavigationStack {
    VStack {
        NavigationLink("Open Details") {
            VStack {
                Text("Preview Details")
            }
            .navigationTitle("Details")
        }
    }
    .navigationTitle("My App")
}
```

## Next preview layers

1. nested NavigationLink destinations
2. alternative NavigationLink destination initializer forms
3. sheets / presentation state
4. animation and transitions
5. richer control styles
6. iPad side-by-side editor/preview layout

## Architecture constraint

Navigation titles remain ordinary portable Preview modifiers. The project and
workspace core do not depend on SwiftUI navigation APIs, and navigation
destinations remain parsed through the same safe provider stack rather than
executing arbitrary source code.
