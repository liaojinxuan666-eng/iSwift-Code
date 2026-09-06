# App Preview Roadmap — Locked

Status: **0.1.3 implementation in progress**

App Preview keeps three separate product paths:

`Run Code | Preview App | Build IPA`

## Completed

- portable Preview IR and signed native runtime
- Live Preview
- primitive and typed optional primitive `@State`
- TextField / Toggle / Picker bindings
- constrained Button action runtime
- NavigationStack / NavigationLink
- navigationTitle
- `.sheet(isPresented:)` and constrained `onDismiss`
- `.fullScreenCover(isPresented:)` and constrained `onDismiss`
- `.sheet(item:)` for optional primitive item state
- `.fullScreenCover(item:)` for optional primitive item state
- built-in Bool and item presentation demos
- portable Identifiable item-model IR foundation
- Identifiable item state/action bridge
- constrained Identifiable source-model parsing
- typed optional custom-model `@State` recognition
- constrained Identifiable model-constructor action lowering
- runtime custom Identifiable item presentation bridge
- direct `Text(item.member)` lowering
- item-member string interpolation in Text
- source-level validation diagnostics for unknown custom item members
- built-in Identifiable sheet/full-screen regression demo catalog
- portable animation/transition modifier IR foundation
- value-driven animation lowering for default/linear/ease/spring curves
- portable opacity/scale/slide/move transition lowering
- portable Button/TextField/Picker/Toggle style foundation
- portable controlSize and tint lowering

## Current custom item Text support

Direct member access:

```swift
Text(item.title)
Text(item.id)
```

Member interpolation:

```swift
Text("Title: \(item.title)")
Text("ID: \(item.id)")
Text("\(item.id): \(item.title)")
```

Unknown members now fail during Preview generation:

```swift
Text(item.notExist)
Text("Value: \(item.notExist)")
```

Example diagnostic:

```text
Identifiable preview model 'DetailItem' has no stored member 'notExist'.
Available members: id, title.
```

Validation happens before runtime member lookup, so invalid source no longer
silently renders an empty string.

The validator is source-only and portable. It never executes the source model,
property getters, presentation closures, or interpolation expressions.

## Built-in custom-item regression demos

`PreviewIdentifiableDemoCatalog` now keeps source fixtures for both:

- `.sheet(item:)`
- `.fullScreenCover(item:)`

Each successful fixture exercises the same path used by user files:

```text
Identifiable source model
→ typed optional @State
→ constructor Button action
→ portable item state
→ item presentation
→ direct item.member
→ interpolated item.member
→ clear back to nil
```

A deliberately invalid fixture also verifies that an unknown member produces a
Preview diagnostic before runtime rendering.

These fixtures are regression inputs only; they do not execute source SwiftUI
code directly.

## Motion foundation

The first portable motion layer supports:

```swift
.animation(.default, value: state)
.animation(.linear, value: state)
.animation(.easeIn, value: state)
.animation(.easeOut, value: state)
.animation(.easeInOut(duration: 0.25), value: state)
.animation(.spring(), value: state)

.transition(.opacity)
.transition(.scale)
.transition(.slide)
.transition(.move(edge: .leading))
```

Animation values are constrained to known preview `@State` identifiers.
The runtime maps portable motion metadata to native SwiftUI `Animation` and
`AnyTransition` values.

Transition metadata is now preserved end-to-end. The next motion step is
portable conditional insertion/removal so transitions can visibly activate
when preview state changes.

Source animation expressions themselves are never executed.

## Control-style foundation

"Richer control styles" means Preview no longer forces every control into one
fixed appearance. Common SwiftUI control styles are preserved in portable
Preview IR and rendered by the signed native runtime.

First-wave support:

```swift
.buttonStyle(.automatic)
.buttonStyle(.plain)
.buttonStyle(.borderless)
.buttonStyle(.bordered)
.buttonStyle(.borderedProminent)

.textFieldStyle(.automatic)
.textFieldStyle(.plain)
.textFieldStyle(.roundedBorder)

.pickerStyle(.automatic)
.pickerStyle(.menu)
.pickerStyle(.segmented)
.pickerStyle(.wheel)
.pickerStyle(.inline)

.toggleStyle(.automatic)
.toggleStyle(.switch)
.toggleStyle(.button)

.controlSize(.mini)
.controlSize(.small)
.controlSize(.regular)
.controlSize(.large)

.tint(.blue)
```

The runtime no longer hard-codes every Button as `borderedProminent`, every
TextField as `roundedBorder`, or every Picker as `menu`. Unstyled controls now
use native SwiftUI defaults, while explicitly styled controls keep the source
appearance.

Next control-style work can add button roles, Label/image button content,
disabled state, text input options, and more safe style modifiers.

## Existing paths remain unchanged

- primitive `Text(item)` item presentation
- direct custom `Text(item.member)`
- custom item-member interpolation
- ordinary `Text("\(state)")` preview interpolation
- primitive Button actions
- custom Identifiable constructor actions

## Next preview layers

1. richer control-style coverage and labels
2. conditional visibility / insertion-removal for active transitions
3. iPad side-by-side editor/preview layout

## Architecture constraint

Item presentation remains provider-driven and portable. The generic project,
workspace, and plugin core never executes arbitrary presentation closures,
model constructors, property getters, interpolation expressions, or
user-supplied SwiftUI runtime code.
