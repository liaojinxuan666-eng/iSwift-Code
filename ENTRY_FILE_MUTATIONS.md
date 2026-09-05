# Entry File Mutations

Status: **0.1.2 descriptor/file transaction layer**

The project descriptor and project files can now change together without
leaving stale entry-file metadata.

## Supported operations

- Set any existing project file as the entry file.
- Clear the entry file.
- Rename the current entry file.
- Delete the current entry file.
- Persist all of the above in `project.json`.

## Transaction behavior

For persistent projects, `ProjectStore` coordinates file mutations and
descriptor writes.

### Rename entry file

1. validate source/destination
2. move the file
3. atomically save the updated descriptor
4. if descriptor saving fails, move the file back

### Delete entry file

1. validate the replacement entry, if any
2. retain the original file bytes in memory
3. delete the file
4. atomically save the updated descriptor
5. if descriptor saving fails, restore the file

This is not a database transaction, but it prevents the common failure mode
where `project.json` points to an old path after a successful file operation.

## Session behavior

`ProjectSessionViewModel` now publishes the current descriptor so entry changes
immediately update the UI.

When the active entry file is deleted, the session selects the first remaining
recognized source file as the replacement entry. If no source file remains, the
project intentionally has no entry file until the user selects one.

The file context menu now exposes `Set as Entry`, and entry files are marked
with a flag.

## Architectural boundary

Entry-file mutation remains project infrastructure. It contains no Clang,
Codex, or app-specific logic.

The only editor convenience is automatic replacement selection from source
files already recognized by the generic `ProjectSourceLanguageResolver`.
