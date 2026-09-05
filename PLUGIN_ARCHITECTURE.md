# iSwift Code Plugin Architecture

Status: **locked foundation for 0.1.2**

The plugin system is designed as a reusable development-platform layer, not as
an unrestricted dynamic-code loader.

## Core rule

Plugins never receive direct unrestricted access to iSwift Code internals.

Every plugin must declare:

- a stable reverse-domain identifier
- a display name and version
- the iSwift Plugin API version it targets
- one or more capabilities
- every host permission it requires
- its execution mode

The host registry validates those declarations before the plugin can activate.

## Capability model

The initial capability vocabulary is:

- `compiler`
- `aiAssistant`
- `editor`
- `build`
- `projectTemplate`
- `runtime`
- `formatter`
- `languageServer`

A plugin may expose more than one capability.

Examples:

- a future Clang/LLVM integration is primarily a `compiler` plugin and may also
  expose `formatter` or `languageServer`
- a Codex-like coding provider is primarily an `aiAssistant` plugin
- an IPA pipeline component is a `build` plugin

## Execution modes

### Built-in

Code ships with iSwift Code and is linked or bundled with the application.

This is the preferred mode for low-level toolchains that need native code and
are deliberately shipped as part of the app, such as a future Clang/LLVM
integration.

Built-in does **not** mean a downloaded arbitrary dylib.

### WebAssembly

Portable plugin logic executes inside a host-controlled WebAssembly sandbox.

This is the preferred future direction for third-party executable plugins on a
normal non-jailbroken iOS device because the host can expose a narrow API and
keep plugin execution isolated from app internals.

### Remote service

The local plugin object is a provider/proxy for a network service.

This is the intended model for Codex-like AI services and other cloud-backed
developer tools. Remote-service plugins must request the `network` permission
and may separately request `credentials`, workspace access, or other
capabilities.

## Permission model

Plugin permissions are iSwift Code host permissions. They do not bypass or
replace iOS sandbox permissions.

The initial permissions are:

- `workspaceRead`
- `workspaceWrite`
- `network`
- `userFiles`
- `clipboard`
- `credentials`
- `buildArtifacts`
- `openExternalURL`

A plugin cannot activate unless the host grants every permission declared as
required by its manifest.

Future host services must check these permissions again at the service boundary;
activation-time checking is not the only security layer.

## Lifecycle

The first registry lifecycle is:

`registered -> enabled -> active`

A plugin can also be disabled or unregistered. Disabling or unregistering an
active plugin first deactivates it.

The registry owns lifecycle state. Plugins do not get to mark themselves active
or bypass registration.

## API compatibility

Plugin API version 1 is the first compatibility contract.

The registry rejects plugins targeting a different API version. Future host
versions may add compatibility ranges, migrations, or adapters, but plugin code
must never silently run against an incompatible host API.

## What 0.1.2 foundation deliberately does not implement yet

- downloading/installing plugin bundles
- WebAssembly execution
- remote AI HTTP clients
- Clang/LLVM embedding
- plugin UI
- persistent enable/disable state
- credential storage
- host filesystem/network service implementations
- a public plugin marketplace

Those layers will be built on top of the manifest, permission, protocol, and
registry contracts introduced here.

## Stock iOS constraint

On a normal non-jailbroken iOS device, the plugin architecture will not depend
on downloading and dynamically executing arbitrary native dylibs.

Native toolchains intended to ship with iSwift Code belong in the built-in
execution mode. Third-party executable extensions should prefer WebAssembly,
while network-backed services use the remote-service provider model.
