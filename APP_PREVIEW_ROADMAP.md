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
- portable Label and label-backed Button content
- portable destructive/cancel Button roles
- portable labelStyle and disabled modifiers
- portable SecureField using String preview state
- portable keyboard type and submit-label behavior
- portable text-input autocapitalization/autocorrection behavior
- portable labelsHidden control modifier
- Bool @State conditional insertion/removal
- negated Bool conditions and simple else branches
- active transition path through conditional branches

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

Transition metadata is now preserved end-to-end, and Bool `@State` driven
conditional insertion/removal is active. A transition on a conditional child
can now participate in native SwiftUI insertion/removal animation when the
surrounding source uses a supported value-driven `.animation(..., value:)`.

First-wave condition grammar:

```swift
if showingDetails {
    Text("Details")
        .transition(.opacity)
}

if !isLoading {
    Text("Ready")
} else {
    Text("Loading")
}
```

Conditions are restricted to one known Bool preview state, optionally negated.
The condition expression itself is never executed from user source.

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

Second-wave control content now adds literal `Label` + SF Symbol content,
label-backed Buttons, destructive/cancel Button roles, `.labelStyle(...)`, and
both literal and Bool-`@State` driven `.disabled(...)`.

Button closures still travel through the existing constrained
`PreviewActionProgram` path; richer control content does not execute arbitrary
source closures.

The text-input layer now also preserves `SecureField`, keyboard type,
autocapitalization, autocorrection, submit-label behavior, and `labelsHidden`.
These values remain portable metadata and are applied only by the signed native
runtime.

## Text-input behavior

Portable input behavior now supports:

```swift
SecureField("Password", text: $password)

TextField("Email", text: $email)
    .keyboardType(.emailAddress)
    .textInputAutocapitalization(.never)
    .autocorrectionDisabled()
    .submitLabel(.done)

Toggle("Remember", isOn: $remember)
    .labelsHidden()
```

Supported keyboard types include the common iOS keyboard families such as
default, ASCII, URL, number/phone pads, email, decimal, Twitter, and web search.

The provider never receives or executes a keyboard callback. It lowers source
configuration into portable PreviewModifier values and the signed SwiftUI
runtime applies the matching native environment modifiers.

## Existing paths remain unchanged

- primitive `Text(item)` item presentation
- direct custom `Text(item.member)`
- custom item-member interpolation
- ordinary `Text("\(state)")` preview interpolation
- primitive Button actions
- custom Identifiable constructor actions

## Next preview layers

1. richer conditional expressions / collection-style preview nodes
2. additional safe SwiftUI layout/control modifiers
3. iPad side-by-side editor/preview layout

## Architecture constraint

Item presentation remains provider-driven and portable. The generic project,
workspace, and plugin core never executes arbitrary presentation closures,
model constructors, property getters, interpolation expressions, or
user-supplied SwiftUI runtime code.
