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

The request model carries:

- operation: `check`, `compile`, or `run`
- one or more logical source files
- source language
- optional entry file
- optional command-line arguments

The result model carries:

- normalized diagnostics
- console output
- optional build artifacts
- provider metrics

The current `SandboxSwiftCompiler` remains the low-level engine, while
`SandboxSwiftCompilerProvider` is the first built-in compiler plugin and is now
the default compiler used by `EditorViewModel`.

The sandbox provider intentionally accepts only one Swift source file today.
The provider contract itself already supports multiple files so the later
project system and Clang/LLVM provider do not require another API redesign.

### AIProvider

AI coding services use a separate `AIProvider` contract.

The initial task vocabulary includes:

- chat
- explain diagnostics
- generate code
- edit workspace
- review workspace

AI responses may include proposed file edits. Applying those edits remains a
host responsibility; an AI provider does not gain implicit write access simply
because it returned edits.

A future Codex integration belongs here as a `remoteService` plugin. It will
request `network`, and only request workspace/credential permissions needed by
the selected feature.

### WasmPluginLoader

`WasmPluginLoader` is now a reserved host boundary for third-party executable
plugins. 0.1.2 defines the package and resource-limit contracts but deliberately
does not ship a WebAssembly runtime yet.

This keeps Wasm execution replaceable while preserving the plugin manifest,
permissions, lifecycle, and provider APIs.

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

## Lifecycle and discovery

The registry lifecycle remains:

`registered -> enabled -> active`

The registry now also performs typed discovery:

- compiler plugins through `compilerProviders()`
- AI plugins through `aiProviders()`

Disabled providers are hidden from normal discovery unless the caller
explicitly asks to include them.

The registry owns lifecycle state. Plugins do not get to mark themselves active
or bypass registration.

## API compatibility

Plugin API version 1 is the first compatibility contract.

The registry rejects plugins targeting a different API version. Future host
versions may add compatibility ranges, migrations, or adapters, but plugin code
must never silently run against an incompatible host API.

## What 0.1.2 deliberately does not implement yet

- downloading/installing plugin bundles
- WebAssembly execution
- remote AI HTTP clients
- Codex authentication
- Clang/LLVM embedding
- plugin management UI
- persistent enable/disable state
- credential storage
- host filesystem/network service implementations
- a public plugin marketplace

Those layers are built on top of the manifest, permission, protocol, registry,
and provider contracts introduced here.

## Stock iOS constraint

On a normal non-jailbroken iOS device, the plugin architecture will not depend
on downloading and dynamically executing arbitrary native dylibs.

Native toolchains intended to ship with iSwift Code belong in the built-in
execution mode. Third-party executable extensions should prefer WebAssembly,
while network-backed services use the remote-service provider model.
