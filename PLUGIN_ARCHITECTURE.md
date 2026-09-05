# iSwift Code Plugin Architecture

Status: **locked foundation for 0.1.2**

The plugin system is a reusable development-platform layer, not an unrestricted
dynamic-code loader.

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

The architecture is provider-agnostic, toolchain-agnostic, and app-agnostic.
Clang, Codex-like services, the sandbox Swift compiler, and future providers are
implementations of common contracts; none of them define the plugin core.

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

## Provider layer

0.1.2 adds typed provider contracts on top of the generic plugin lifecycle.

### CompilerProvider

Compiler plugins are discovered through `CompilerProvider` rather than by
hard-coding a concrete compiler class into the editor.

The request model already supports multiple logical source files, languages,
entry-file selection, arguments, normalized diagnostics, artifacts, and
provider metrics.

The current `SandboxSwiftCompilerProvider` is only the first built-in
implementation. It intentionally supports one Swift file today while the
provider contract stays broad enough for later Clang/LLVM and Swift/Wasm
providers.

### AIProvider

AI coding services use a separate `AIProvider` contract.

The initial task vocabulary includes:

- chat
- explain diagnostics
- generate code
- edit workspace
- review workspace

AI responses may propose file edits, but returning an edit does not grant the AI
provider permission to apply it. Applying edits remains a host-controlled
operation.

A future Codex-like integration belongs here as a `remoteService` provider, not
as a special case in the plugin core.

### WasmPluginLoader

`WasmPluginLoader` is the reserved execution boundary for third-party
executable plugins. The package and resource-limit contracts exist before a
specific WebAssembly runtime is selected.

## Host Services

0.1.2 now has a typed Host Services boundary.

A plugin never receives raw workspace, network, credential, clipboard, build,
document-picker, or external-URL implementations. During activation it receives
a `PluginHostContext`, which exposes a permission-checked `PluginHostServices`
facade.

Host services currently define backend contracts for:

- workspace listing, read, write, delete, and move
- network requests
- credential read/write/remove
- clipboard read/write
- user-file import/export
- build-artifact list/read/write
- opening external URLs

The app supplies the actual backend implementations. This separation allows the
same plugin API to work with a future project system, different credential
stores, different network implementations, and test doubles without exposing
app internals.

Permission checks happen twice:

1. activation rejects a plugin if any required manifest permission was not
   granted
2. every Host Service operation checks its permission again at the service
   boundary

Plugin API v1 also follows least privilege: even if the host caller accidentally
passes extra permissions to `PluginRegistry.activate`, the plugin context
receives only permissions that the plugin declared as required in its manifest.

This means, for example, a formatter that declares only `workspaceRead` and
`workspaceWrite` cannot obtain `network` merely because the application has a
network backend available.

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

`workspaceWrite` does not implicitly grant `workspaceRead`; permissions remain
independent so the host can express narrow capabilities.

## Lifecycle and discovery

The registry lifecycle remains:

`registered -> enabled -> active`

The registry performs typed discovery:

- compiler plugins through `compilerProviders()`
- AI plugins through `aiProviders()`

Disabled providers are hidden from normal discovery unless explicitly included.

The registry owns lifecycle state. Plugins do not get to mark themselves active
or bypass registration.

## API compatibility

Plugin API version 1 is the first compatibility contract.

The registry rejects plugins targeting a different API version. Future host
versions may add compatibility ranges, migrations, optional permissions, or
adapters, but plugin code must never silently run against an incompatible host
API.

## What 0.1.2 deliberately does not implement yet

- downloading/installing plugin bundles
- WebAssembly execution
- a production remote AI HTTP provider
- Codex authentication
- Clang/LLVM embedding
- plugin management UI
- persistent enable/disable state
- production Keychain credential backend
- project-system workspace backend
- user-facing permission approval UI
- a public plugin marketplace

Those layers build on the manifest, provider, permission, registry, and Host
Services contracts instead of bypassing them.

## Stock iOS constraint

On a normal non-jailbroken iOS device, the plugin architecture will not depend
on downloading and dynamically executing arbitrary native dylibs.

Native toolchains intended to ship with iSwift Code belong in the built-in
execution mode. Third-party executable extensions should prefer WebAssembly,
while network-backed services use the remote-service provider model.
