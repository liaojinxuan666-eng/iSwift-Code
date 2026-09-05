import Foundation
import XCTest
@testable import iSwiftCode

final class ProjectEntryMutationTests: XCTestCase {
    private func makeStore() throws -> (ProjectStore, URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        return (try ProjectStore(rootURL: root), root)
    }

    func testDescriptorCanReplaceEntryFileWithoutChangingOtherMetadata() throws {
        let original = ProjectDescriptor(
            identifier: "tests.descriptor",
            displayName: "Descriptor",
            entryFilePath: try WorkspacePath("main.swift"),
            attributes: ["toolchain": "default"]
        )

        let replacement = try WorkspacePath("Sources/App.swift")
        let updated = original.replacingEntryFilePath(replacement)

        XCTAssertEqual(updated.identifier, original.identifier)
        XCTAssertEqual(updated.displayName, original.displayName)
        XCTAssertEqual(updated.schemaVersion, original.schemaVersion)
        XCTAssertEqual(updated.attributes, original.attributes)
        XCTAssertEqual(updated.entryFilePath, replacement)
    }

    func testWorkspaceDescriptorReplacementKeepsFiles() throws {
        let storage = InMemoryProjectWorkspaceStorage()
        let main = try WorkspacePath("main.swift")
        let alt = try WorkspacePath("App.swift")

        try storage.writeFile(Data("print(1)".utf8), at: main)
        try storage.writeFile(Data("print(2)".utf8), at: alt)

        let workspace = try ProjectWorkspace(
            descriptor: ProjectDescriptor(
                identifier: "tests.workspace-descriptor",
                displayName: "Workspace",
                entryFilePath: main
            ),
            storage: storage
        )

        let updatedDescriptor = workspace.descriptor.replacingEntryFilePath(alt)
        let updatedWorkspace = try workspace.replacingDescriptor(updatedDescriptor)

        XCTAssertEqual(updatedWorkspace.descriptor.entryFilePath, alt)
        XCTAssertEqual(try updatedWorkspace.listFiles(), [alt, main])
    }

    func testPersistentSetEntrySurvivesReopen() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }

        let main = try WorkspacePath("main.swift")
        let app = try WorkspacePath("Sources/App.swift")

        _ = try store.createProject(
            descriptor: ProjectDescriptor(
                identifier: "tests.set-entry",
                displayName: "Set Entry",
                entryFilePath: main
            ),
            initialFiles: [
                main: Data("print(1)".utf8),
                app: Data("print(2)".utf8)
            ]
        )

        let updated = try store.setEntryFile(
            projectIdentifier: "tests.set-entry",
            path: app
        )

        XCTAssertEqual(updated.descriptor.entryFilePath, app)
        XCTAssertEqual(
            try store.openProject(identifier: "tests.set-entry").descriptor.entryFilePath,
            app
        )
    }

    func testRenamingPersistentEntryUpdatesDescriptorAndFile() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }

        let main = try WorkspacePath("main.swift")
        let renamed = try WorkspacePath("Sources/App.swift")

        _ = try store.createProject(
            descriptor: ProjectDescriptor(
                identifier: "tests.rename-entry",
                displayName: "Rename Entry",
                entryFilePath: main
            ),
            initialFiles: [
                main: Data("print(42)".utf8)
            ]
        )

        let updated = try store.renameFile(
            projectIdentifier: "tests.rename-entry",
            from: main,
            to: renamed
        )

        XCTAssertEqual(updated.descriptor.entryFilePath, renamed)
        XCTAssertFalse(try updated.contains(main))
        XCTAssertTrue(try updated.contains(renamed))
        XCTAssertEqual(try updated.readTextFile(at: renamed), "print(42)")

        let reopened = try store.openProject(identifier: "tests.rename-entry")
        XCTAssertEqual(reopened.descriptor.entryFilePath, renamed)
    }

    func testDeletingPersistentEntryCanSelectReplacement() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }

        let main = try WorkspacePath("main.swift")
        let fallback = try WorkspacePath("Fallback.swift")

        _ = try store.createProject(
            descriptor: ProjectDescriptor(
                identifier: "tests.delete-entry",
                displayName: "Delete Entry",
                entryFilePath: main
            ),
            initialFiles: [
                main: Data("print(1)".utf8),
                fallback: Data("print(2)".utf8)
            ]
        )

        let updated = try store.deleteFile(
            projectIdentifier: "tests.delete-entry",
            at: main,
            replacementEntryFile: fallback
        )

        XCTAssertFalse(try updated.contains(main))
        XCTAssertEqual(updated.descriptor.entryFilePath, fallback)

        let reopened = try store.openProject(identifier: "tests.delete-entry")
        XCTAssertEqual(reopened.descriptor.entryFilePath, fallback)
    }
}

@MainActor
final class ProjectSessionEntryMutationTests: XCTestCase {
    private func makeSession() throws -> ProjectSessionViewModel {
        let storage = InMemoryProjectWorkspaceStorage()
        let main = try WorkspacePath("main.swift")
        let helper = try WorkspacePath("Helper.swift")

        try storage.writeFile(Data("print(1)".utf8), at: main)
        try storage.writeFile(Data("print(2)".utf8), at: helper)

        let workspace = try ProjectWorkspace(
            descriptor: ProjectDescriptor(
                identifier: "tests.session-entry",
                displayName: "Session Entry",
                entryFilePath: main
            ),
            storage: storage
        )

        return try ProjectSessionViewModel(
            compiler: SandboxSwiftCompilerProvider(),
            workspace: workspace,
            preferredActiveFile: main
        )
    }

    func testSessionCanSwitchEntryFile() throws {
        let model = try makeSession()
        let helper = try WorkspacePath("Helper.swift")

        try model.setEntryFile(helper)

        XCTAssertEqual(model.entryFilePath, helper)
        XCTAssertEqual(
            try model.snapshotIncludingUnsavedChanges().descriptor.entryFilePath,
            helper
        )
    }

    func testSessionCanRenameEntryFile() throws {
        let model = try makeSession()
        let main = try WorkspacePath("main.swift")
        let renamed = try WorkspacePath("Sources/App.swift")

        try model.renameFile(from: main, to: renamed)

        XCTAssertEqual(model.entryFilePath, renamed)
        XCTAssertEqual(model.activeFilePath, renamed)
        XCTAssertFalse(model.files.contains(main))
        XCTAssertTrue(model.files.contains(renamed))
    }

    func testDeletingEntryAutomaticallyChoosesAnotherSource() throws {
        let model = try makeSession()
        let main = try WorkspacePath("main.swift")
        let helper = try WorkspacePath("Helper.swift")

        try model.deleteFile(at: main)

        XCTAssertEqual(model.entryFilePath, helper)
        XCTAssertEqual(model.activeFilePath, helper)
        XCTAssertFalse(model.files.contains(main))
    }
}
