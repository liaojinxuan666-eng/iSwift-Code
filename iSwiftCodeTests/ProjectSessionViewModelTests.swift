import Foundation
import XCTest
@testable import iSwiftCode

@MainActor
final class ProjectSessionViewModelTests: XCTestCase {
    private func makeModel(
        files: [(String, String)],
        entry: String = "main.swift"
    ) throws -> ProjectSessionViewModel {
        let storage = InMemoryProjectWorkspaceStorage()

        for item in files {
            try storage.writeFile(
                Data(item.1.utf8),
                at: WorkspacePath(item.0)
            )
        }

        let workspace = try ProjectWorkspace(
            descriptor: ProjectDescriptor(
                identifier: "tests.session",
                displayName: "Session Test",
                entryFilePath: try WorkspacePath(entry)
            ),
            storage: storage
        )

        return try ProjectSessionViewModel(
            compiler: SandboxSwiftCompilerProvider(),
            workspace: workspace,
            preferredActiveFile: try WorkspacePath(entry)
        )
    }

    func testInitialFileListAndEntrySelection() throws {
        let model = try makeModel(
            files: [
                ("main.swift", "print(42)"),
                ("README.md", "Hello")
            ]
        )

        XCTAssertEqual(model.files.map(\.value), ["README.md", "main.swift"])
        XCTAssertEqual(model.activeFilePath, try WorkspacePath("main.swift"))
        XCTAssertEqual(model.source, "print(42)")
        XCTAssertFalse(model.isActiveFileDirty)
    }

    func testEditingMarksOnlyActiveFileDirtyAndSwitchPreservesBuffer() throws {
        let model = try makeModel(
            files: [
                ("main.swift", "print(1)"),
                ("Notes.txt", "old")
            ]
        )

        model.source = "print(2)"
        XCTAssertEqual(model.dirtyFilePaths, [try WorkspacePath("main.swift")])

        try model.selectFile(WorkspacePath("Notes.txt"))
        XCTAssertEqual(model.source, "old")

        try model.selectFile(WorkspacePath("main.swift"))
        XCTAssertEqual(model.source, "print(2)")
        XCTAssertTrue(model.isActiveFileDirty)
    }

    func testSaveActivePersistsBuffer() throws {
        let storage = InMemoryProjectWorkspaceStorage()
        let main = try WorkspacePath("main.swift")
        try storage.writeFile(Data("print(1)".utf8), at: main)

        let workspace = try ProjectWorkspace(
            descriptor: ProjectDescriptor(
                identifier: "tests.save",
                displayName: "Save",
                entryFilePath: main
            ),
            storage: storage
        )

        let model = try ProjectSessionViewModel(
            compiler: SandboxSwiftCompilerProvider(),
            workspace: workspace,
            preferredActiveFile: main
        )

        model.source = "print(99)"
        try model.saveActiveFile()

        XCTAssertFalse(model.isActiveFileDirty)
        XCTAssertEqual(try workspace.readTextFile(at: main), "print(99)")
    }

    func testCreateRenameDeleteSecondaryFile() throws {
        let model = try makeModel(files: [("main.swift", "print(42)")])

        let helper = try WorkspacePath("Sources/Helper.swift")
        try model.createFile(at: helper, contents: "let helper = 1")

        XCTAssertTrue(model.files.contains(helper))
        XCTAssertEqual(model.activeFilePath, helper)

        let renamed = try WorkspacePath("Sources/Support.swift")
        try model.renameFile(from: helper, to: renamed)

        XCTAssertFalse(model.files.contains(helper))
        XCTAssertTrue(model.files.contains(renamed))
        XCTAssertEqual(model.activeFilePath, renamed)

        try model.deleteFile(at: renamed)

        XCTAssertFalse(model.files.contains(renamed))
        XCTAssertEqual(model.activeFilePath, try WorkspacePath("main.swift"))
    }

    func testEntryFileCanBeRenamedAndDeleted() throws {
        let model = try makeModel(files: [("main.swift", "print(42)")])
        let main = try WorkspacePath("main.swift")
        let renamed = try WorkspacePath("renamed.swift")

        try model.renameFile(from: main, to: renamed)

        XCTAssertEqual(model.entryFilePath, renamed)
        XCTAssertEqual(model.activeFilePath, renamed)
        XCTAssertFalse(model.files.contains(main))
        XCTAssertTrue(model.files.contains(renamed))
        XCTAssertEqual(model.source, "print(42)")

        try model.deleteFile(at: renamed)

        XCTAssertNil(model.entryFilePath)
        XCTAssertNil(model.activeFilePath)
        XCTAssertTrue(model.files.isEmpty)
        XCTAssertEqual(model.source, "")
    }

    func testSnapshotIncludesUnsavedEditorBuffer() throws {
        let model = try makeModel(files: [("main.swift", "print(1)")])
        model.source = "print(42)"

        let snapshot = try model.snapshotIncludingUnsavedChanges()
        let main = try WorkspacePath("main.swift")

        XCTAssertEqual(snapshot.file(at: main)?.text, "print(42)")
    }

    func testRunUsesUnsavedEntryBuffer() throws {
        let model = try makeModel(files: [("main.swift", "print(1)")])
        model.source = "print(40 + 2)"

        model.run()

        XCTAssertTrue(model.diagnostics.isEmpty)
        XCTAssertEqual(
            model.consoleOutput.trimmingCharacters(in: .whitespacesAndNewlines),
            "42"
        )
        XCTAssertTrue(model.buildSummary.contains("Succeeded"))
    }

    func testSelectingBinaryFileDoesNotReplaceCurrentEditor() throws {
        let storage = InMemoryProjectWorkspaceStorage()
        let main = try WorkspacePath("main.swift")
        let binary = try WorkspacePath("Assets/blob.bin")

        try storage.writeFile(Data("print(42)".utf8), at: main)
        try storage.writeFile(Data([0xFF, 0xFE, 0xFD]), at: binary)

        let workspace = try ProjectWorkspace(
            descriptor: ProjectDescriptor(
                identifier: "tests.binary",
                displayName: "Binary",
                entryFilePath: main
            ),
            storage: storage
        )

        let model = try ProjectSessionViewModel(
            compiler: SandboxSwiftCompilerProvider(),
            workspace: workspace,
            preferredActiveFile: main
        )

        XCTAssertThrowsError(try model.selectFile(binary)) { error in
            XCTAssertEqual(
                error as? ProjectSessionError,
                .fileIsNotUTF8(binary)
            )
        }

        XCTAssertEqual(model.activeFilePath, main)
        XCTAssertEqual(model.source, "print(42)")
    }
}
