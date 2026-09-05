# Project Session / Multi-file Editor

Status: **0.1.2 editor-session foundation**

This milestone moves visible editor state onto the generic project model.

## ProjectSessionViewModel

The session owns:

- project file list
- active-file selection
- per-file text buffers
- dirty-file tracking
- save active / save all
- create / rename / delete
- compiler execution from a project snapshot
- console and diagnostic state

`ProjectWorkspace` remains responsible for persistence. The session is a UI
layer over that workspace rather than a replacement storage system.

## Unsaved buffers

Switching files does not discard unsaved edits.

Buffers are held by project-relative `WorkspacePath`. A compiler run builds a
snapshot that overlays unsaved buffers on persisted workspace contents, so
"Run" does not need to silently save the project first.

This same snapshot model can later be handed to AI review/edit workflows.

## Entry file

For 0.1.2, the configured entry file cannot be renamed or deleted from the
session UI. Entry-file mutation needs a proper descriptor-update/persistence
contract and will be added separately rather than leaving stale project
metadata.

## UI

The current phone-friendly workspace UI adds:

- horizontal file strip
- active file selection
- dirty indicators
- New File
- Save / Save All
- context-menu Rename / Delete
- project-relative path entry
- generic source editor accessibility label

The file strip is only one UI representation of the session. iPad/mac-style
sidebars can be added later without changing the session API.

## Current compiler limitation

The workspace/session are multi-file.

The built-in Sandbox Swift provider still supports exactly one recognized source
file. Creating a second `.swift` source file may therefore be rejected when
running through that provider.

This is a provider capability limitation, not a Project Session limitation.
Future multi-file Swift or Clang providers can consume the same project
snapshot without redesigning the editor.
