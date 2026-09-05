# iSwift Code Project Workspace

Status: **0.1.2 workspace foundation**

The project layer is a generic multi-file workspace used by the editor,
compiler providers, build providers, AI providers, and plugin Host Services.

It is deliberately independent from Swift, Clang, Codex-like services, Arcadia,
or any one future application.

## Core types

### `WorkspacePath`

All workspace paths are canonical project-relative paths.

The type rejects:

- absolute paths
- `.` and `..`
- backslash separators
- empty path components
- null bytes

This prevents callers from using project APIs as arbitrary filesystem APIs.

### `ProjectDescriptor`

Portable project metadata contains:

- project identifier
- display name
- project schema version
- optional entry file
- generic string attributes

Toolchain-specific settings do not belong in the descriptor core.

### `ProjectWorkspaceStorage`

Storage is replaceable.

0.1.2 includes `DirectoryProjectWorkspaceStorage`, while tests use an in-memory
backend. Future storage implementations can support imported document folders,
cloud-backed projects, archives, or other persistence without changing the
workspace API.

### `ProjectWorkspace`

The workspace provides:

- list files
- read/write binary files
- read/write UTF-8 text
- move/delete
- entry-file resolution
- immutable project snapshots

A snapshot is suitable for feeding compiler/AI/build layers without handing
those layers direct filesystem access.

## Plugin integration

`ProjectWorkspacePluginBackend` implements `PluginWorkspaceHostBackend`.

This means the permission path is:

`Plugin -> PluginHostServices -> ProjectWorkspacePluginBackend -> ProjectWorkspace -> Storage`

Plugins never receive the workspace object or filesystem root directly.

## Next integration step

The next layer will build provider requests from a workspace snapshot:

- source-language classification
- multi-file `CompilerRequest`
- AI workspace snapshots
- editor project state

The existing single-file editor can then migrate onto the same project model
without changing the plugin or provider contracts.
