# Project Persistence

Status: **0.1.2 persistent project foundation**

Projects now have a persistent on-disk representation.

## Layout

Each project is isolated below the Project Store root:

```text
Projects/
└── <project identifier>/
    ├── .iswift/
    │   └── project.json
    ├── Sources/
    ├── Resources/
    └── other project files
```

The `.iswift` directory is metadata owned by iSwift Code.

`DirectoryProjectWorkspaceStorage` already skips hidden files, so `.iswift`
does not appear in:

- editor file lists
- compiler requests
- AI workspace snapshots
- plugin workspace listings

## ProjectStore

`ProjectStore` provides:

- create project
- open project
- open-or-create
- list projects
- save descriptor
- delete project
- Application Support default location

Descriptors are written atomically as JSON.

A directory identifier and descriptor identifier must match, preventing project
metadata from silently pointing at the wrong project.

## Scratch project migration

The default Scratch Project now uses:

`Application Support/iSwift Code/Projects/iswift.scratch`

instead of an in-memory-only workspace.

On a normal launch:

1. open the existing scratch project if present
2. otherwise create it with the welcome `main.swift`
3. never replace existing user source during subsequent launches

If Application Support cannot be created or opened, the editor falls back to
the same in-memory workspace API so storage failure does not make the app
unusable.

## What this enables next

The persistent descriptor API is now available for:

- changing the entry file safely
- renaming/deleting an entry file while updating metadata
- a project browser
- multiple saved projects
- project templates
- build/toolchain settings stored as project metadata

The next layer should make descriptor mutation transactional with file
operations so an entry-file rename cannot leave stale metadata.
