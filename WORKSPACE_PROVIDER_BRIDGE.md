# Workspace Provider Bridge

Status: **0.1.2 provider/workspace integration**

This layer connects the generic Project Workspace to compiler and AI provider
contracts without introducing provider-specific branches.

## Data flow

Editor:

`CodeEditor -> ProjectWorkspace -> Snapshot -> ProjectProviderBridge -> CompilerProvider`

AI:

`ProjectWorkspace -> Snapshot -> ProjectProviderBridge -> AIProviderRequest`

Plugins:

`Plugin -> Host Services -> ProjectWorkspacePluginBackend -> ProjectWorkspace`

All three paths now share the same workspace model.

## Source classification

`ProjectSourceLanguageResolver` currently recognizes:

- `.swift`
- `.c`
- `.cc`, `.cpp`, `.cxx`
- `.m`
- `.mm`

The resolver classifies source files only. It does not decide which compiler
provider should handle them. Provider selection remains a separate registry
responsibility.

Non-source files remain in the project snapshot and are available to AI and
other project-aware tools, but are not inserted into `CompilerRequest`.

## AI snapshots

AI requests receive UTF-8 project files. Binary files are omitted from the
text-oriented `AIWorkspaceFile` contract.

This is intentionally only a transport conversion. An AI provider still needs
workspace permissions through Host Services before it may apply edits.

## Editor migration

The existing scratch editor now stores its source inside an in-memory
`ProjectWorkspace` before compiling.

The UI remains visually single-file for now, but the execution path is already
project-based. This allows the next UI milestone to add file browsing and
switching without replacing the compiler/provider architecture.

## Next step

Add a project session/view model that exposes:

- file tree/list
- active file selection
- create/rename/delete
- dirty/save state
- persistent directory-backed projects

The existing code editor can then become one view over a general multi-file
project rather than the owner of project state.
