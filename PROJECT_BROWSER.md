# Project Browser / Multiple Projects

Status: **0.1.2 project catalog milestone**

iSwift Code now starts at a persistent project catalog rather than opening one
hard-coded Scratch Project.

## Flow

```text
App Launch
   ↓
ProjectBrowserView
   ↓
ProjectStore
   ├─ Scratch Project
   ├─ Project A
   ├─ Project B
   └─ ...
   ↓
ProjectSessionViewModel
   ↓
WorkspaceView
```

## Project templates

Project creation uses `ProjectTemplate`.

A template defines only:

- display metadata
- initial entry-file path
- initial files
- generic descriptor attributes

It does not select a compiler or AI provider.

0.1.2 ships with:

- `Swift Console`
- `Empty Project`

Future C/C++, SwiftUI/App Preview, game, build-system, or third-party templates
can use the same contract.

## Provider independence

`ProjectBrowserViewModel` accepts a compiler factory.

The browser therefore does not need to know whether a project session later
uses:

- the current Sandbox Swift provider
- a fuller Swift provider
- Clang/LLVM
- another built-in provider
- a plugin-provided compiler

Provider selection can be upgraded separately.

## Persistence

Every project continues to use `ProjectStore`.

Creating, opening, editing, closing, and reopening projects therefore all use
the same persistent project representation introduced earlier.

The existing Scratch Project is preserved as `iswift.scratch`.

## UI

The app root is now the Projects screen.

Users can:

- list saved projects
- create projects
- choose a template
- open a project
- swipe or long-press to delete a project
- navigate back from the editor to the catalog

The project editor itself remains Project Session based.
