import Foundation
import XCTest
@testable import iSwiftCode

final class ProjectStoreTests: XCTestCase {
    private func makeStore() throws -> (ProjectStore, URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        return (
            try ProjectStore(rootURL: root),
            root
        )
    }

    func testCreateAndReopenPreservesDescriptorAndFiles() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }

        let main = try WorkspacePath("Sources/main.swift")
        let descriptor = ProjectDescriptor(
            identifier: "com.example.demo",
            displayName: "Demo",
            entryFilePath: main,
            attributes: ["kind": "scratch"]
        )

        let created = try store.createProject(
            descriptor: descriptor,
            initialFiles: [
                main: Data("print(42)".utf8)
            ]
        )

        XCTAssertEqual(try created.readTextFile(at: main), "print(42)")

        let reopened = try store.openProject(identifier: descriptor.identifier)

        XCTAssertEqual(reopened.descriptor, descriptor)
        XCTAssertEqual(try reopened.readTextFile(at: main), "print(42)")
    }

    func testMetadataIsHiddenFromWorkspaceFiles() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }

        let main = try WorkspacePath("main.swift")
        let descriptor = ProjectDescriptor(
            identifier: "tests.hidden",
            displayName: "Hidden Metadata",
            entryFilePath: main
        )

        let workspace = try store.createProject(
            descriptor: descriptor,
            initialFiles: [
                main: Data("print(1)".utf8)
            ]
        )

        XCTAssertEqual(try workspace.listFiles(), [main])

        let descriptorURL = store
            .projectRootURL(identifier: descriptor.identifier)
            .appendingPathComponent(ProjectStore.metadataDirectoryName)
            .appendingPathComponent(ProjectStore.descriptorFileName)

        XCTAssertTrue(FileManager.default.fileExists(atPath: descriptorURL.path))
    }

    func testOpenOrCreateDoesNotReplaceExistingUserSource() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }

        let main = try WorkspacePath("main.swift")
        let descriptor = ProjectDescriptor(
            identifier: "tests.scratch",
            displayName: "Scratch",
            entryFilePath: main
        )

        let first = try store.openOrCreateProject(
            descriptor: descriptor,
            initialFiles: [
                main: Data("print(1)".utf8)
            ]
        )
        try first.writeTextFile("print(99)", at: main)

        let second = try store.openOrCreateProject(
            descriptor: descriptor,
            initialFiles: [
                main: Data("print(2)".utf8)
            ]
        )

        XCTAssertEqual(try second.readTextFile(at: main), "print(99)")
    }

    func testListProjectsUsesDescriptors() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }

        try store.createProject(
            descriptor: ProjectDescriptor(
                identifier: "tests.beta",
                displayName: "Beta"
            )
        )

        try store.createProject(
            descriptor: ProjectDescriptor(
                identifier: "tests.alpha",
                displayName: "Alpha"
            )
        )

        XCTAssertEqual(
            try store.listProjects().map(\.displayName),
            ["Alpha", "Beta"]
        )
    }

    func testSaveDescriptorPersistsMetadata() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }

        try store.createProject(
            descriptor: ProjectDescriptor(
                identifier: "tests.metadata",
                displayName: "Before"
            )
        )

        let updated = ProjectDescriptor(
            identifier: "tests.metadata",
            displayName: "After",
            entryFilePath: try WorkspacePath("Sources/main.swift"),
            attributes: ["toolchain": "default"]
        )

        try store.saveDescriptor(updated)

        let reopened = try store.openProject(identifier: "tests.metadata")
        XCTAssertEqual(reopened.descriptor, updated)
    }

    func testDuplicateProjectIsRejected() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }

        let descriptor = ProjectDescriptor(
            identifier: "tests.duplicate",
            displayName: "Duplicate"
        )

        _ = try store.createProject(descriptor: descriptor)

        XCTAssertThrowsError(
            try store.createProject(descriptor: descriptor)
        ) { error in
            XCTAssertEqual(
                error as? ProjectStoreError,
                .projectAlreadyExists("tests.duplicate")
            )
        }
    }

    func testDeleteProjectRemovesDirectory() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }

        let descriptor = ProjectDescriptor(
            identifier: "tests.delete",
            displayName: "Delete"
        )

        _ = try store.createProject(descriptor: descriptor)
        XCTAssertTrue(try store.projectExists(identifier: descriptor.identifier))

        try store.deleteProject(identifier: descriptor.identifier)

        XCTAssertFalse(try store.projectExists(identifier: descriptor.identifier))
    }

    func testDescriptorIdentifierMustMatchDirectory() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }

        let descriptor = ProjectDescriptor(
            identifier: "tests.original",
            displayName: "Original"
        )

        _ = try store.createProject(descriptor: descriptor)

        let projectRoot = store.projectRootURL(identifier: descriptor.identifier)
        let descriptorURL = projectRoot
            .appendingPathComponent(ProjectStore.metadataDirectoryName)
            .appendingPathComponent(ProjectStore.descriptorFileName)

        let wrong = ProjectDescriptor(
            identifier: "tests.other",
            displayName: "Wrong"
        )

        let data = try JSONEncoder().encode(wrong)
        try data.write(to: descriptorURL, options: .atomic)

        XCTAssertThrowsError(
            try store.openProject(identifier: descriptor.identifier)
        ) { error in
            XCTAssertEqual(
                error as? ProjectStoreError,
                .descriptorIdentifierMismatch(
                    expected: "tests.original",
                    found: "tests.other"
                )
            )
        }
    }
}
