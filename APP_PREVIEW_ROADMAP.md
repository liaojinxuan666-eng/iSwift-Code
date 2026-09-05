# App Preview Roadmap — Locked

Status: **0.1.3 implementation in progress**

App Preview keeps three separate product paths:

`Run Code | Preview App | Build IPA`

## Completed

- portable Preview IR and signed native runtime
- Live Preview
- primitive `@State`
- TextField / Toggle / Picker bindings
- constrained Button action runtime
- NavigationStack + NavigationLink
- navigationTitle
- multi-page template
- nested NavigationLink destinations

## NavigationLink labeled initializer — current batch

The navigation provider now supports both:

```swift
NavigationLink("Details") {
    Text("Destination")
}
```

and:

```swift
NavigationLink(
    destination: {
        Text("Destination")
    },
    label: {
        Text("Open")
    }
)
```

Both lower to the same portable `PreviewNode.navigationLink` and therefore use
the same signed native runtime path.

The destination still goes through recursive preview parsing, so state-backed
content, interactive controls, actionable Buttons, navigation titles, and
nested NavigationLinks continue to work.

For this first labeled-initializer pass, `label:` intentionally accepts a
literal `Text("...")` label only. This preserves the current portable IR, whose
NavigationLink label is represented as a string title, and avoids silently
dropping arbitrary custom label UI.

## Navigation layer after this batch

The core navigation path now covers:

- NavigationStack
- literal-title NavigationLink
- closure-based destination/label initializer
- nested destinations
- navigationTitle
- shared preview state across destinations

## Next preview layers

1. sheet presentation state
2. full custom NavigationLink label IR
3. animation and transitions
4. richer control styles
5. iPad side-by-side editor/preview layout

## Architecture constraint

Navigation source remains lowered to portable IR. Destination closures are
parsed rather than executed, and unsupported custom labels are rejected instead
of being executed or silently approximated.
