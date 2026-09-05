# App Preview Roadmap — Locked

Status: **0.1.3 implementation in progress**

App Preview keeps three separate product paths:

`Run Code | Preview App | Build IPA`

## Completed before this batch

- portable Preview IR and signed native runtime
- Live Preview
- primitive `@State`
- TextField / Toggle / Picker bindings
- constrained Button action runtime
- NavigationStack / NavigationLink
- labeled + nested NavigationLink forms
- navigationTitle
- `.sheet(isPresented:)`
- built-in multi-page + sheet demo

## Sheet onDismiss — current batch

App Preview now supports the constrained dismissal form:

```swift
@State private var showingInfo = false
@State private var status = "Open"

Text("Root")
    .sheet(
        isPresented: $showingInfo,
        onDismiss: {
            status = "Closed"
        }
    ) {
        Text("Info")
    }
```

The dismissal closure is never executed as arbitrary Swift. The provider lowers
the already-approved mutation subset into `PreviewActionProgram`:

```text
onDismiss source
    ↓
set / add / subtract / toggle lowering
    ↓
PreviewActionValidator
    ↓
PreviewModifier.sheetWithOnDismiss
    ↓
signed Preview Runtime
    ↓
PreviewStateStore.perform(...)
```

Supported dismissal mutations match the existing Button action model:

```swift
status = "Closed"
enabled = false
count = 10
count += 1
count -= 1
enabled.toggle()
```

Unknown state names, incompatible state types, and unsupported statements
produce diagnostics before the runtime receives the presentation IR.

The original `.sheet(isPresented:)` portable case is intentionally preserved
unchanged for backward compatibility.

## Next preview layers

1. `.fullScreenCover(isPresented:)`
2. default template onDismiss example
3. `.sheet(item:)`
4. animation / transitions
5. richer control styles
6. iPad side-by-side editor/preview layout

## Architecture constraint

Presentation callbacks stay inside the same constrained `PreviewActionProgram`
model already used by Buttons. Arbitrary Swift closures are not executed by the
Preview Runtime, and the generic project/workspace/plugin core remains
independent from SwiftUI presentation APIs.
