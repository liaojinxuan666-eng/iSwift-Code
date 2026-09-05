import Foundation
import XCTest
@testable import iSwiftCode

@MainActor
final class ProjectBrowserViewModelTests: XCTestCase {
    private func makeStore() throws -> (ProjectStore, URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                UUID().uuidString,
                isDirectory: true
            )

        return (
            try ProjectStore(rootURL: root),
            root
        )
    }

    func testDefaultSeedCreatesScratchProject() throws {
        let (store, root) = try makeStore()
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let model = ProjectBrowserViewModel(
            store: store,
            seedDefaultProject: true
        )

        XCTAssertEqual(model.projects.count, 1)
        XCTAssertEqual(
            model.projects.first?.identifier,
            "iswift.scratch"
        )
        XCTAssertEqual(
            model.projects.first?.displayName,
            "Scratch Project"
        )

        let workspace = try store.openProject(
            identifier: "iswift.scratch"
        )

        XCTAssertEqual(
            workspace.descriptor.entryFilePath,
            try WorkspacePath("main.swift")
        )
        XCTAssertTrue(
            try workspace.contains(
                WorkspacePath("main.swift")
            )
        )
    }

    func testCreateMultipleProjectsUsesUniqueIdentifiers() throws {
        let (store, root) = try makeStore()
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let model = ProjectBrowserViewModel(
            store: store,
            seedDefaultProject: false
        )

        let first = try model.createProject(
            displayName: "Demo App",
            templateID: "swift-console"
        )

        let second = try model.createProject(
            displayName: "Demo App",
            templateID: "swift-console"
        )

        XCTAssertEqual(first.identifier, "project.demo-app")
        XCTAssertEqual(second.identifier, "project.demo-app.2")
        XCTAssertEqual(model.projects.count, 2)
    }

    func testEmptyTemplateCreatesProjectWithoutEntryFile() throws {
        let (store, root) = try makeStore()
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let model = ProjectBrowserViewModel(
            store: store,
            seedDefaultProject: false
        )

        let descriptor = try model.createProject(
            displayName: "Empty",
            templateID: "empty"
        )

        let workspace = try store.openProject(
            identifier: descriptor.identifier
        )

        XCTAssertNil(workspace.descriptor.entryFilePath)
        XCTAssertEqual(try workspace.listFiles(), [])
    }

    func testSwiftTemplateExpandsProjectName() throws {
        let template = BuiltInProjectTemplates.swiftConsole

        let project = template.instantiate(
            projectIdentifier: "tests.template",
            projectDisplayName: "My Project"
        )

        let main = try WorkspacePath("main.swift")
        let data = try XCTUnwrap(project.initialFiles[main])
        let text = try XCTUnwrap(
            String(data: data, encoding: .utf8)
        )

        XCTAssertTrue(text.contains("My Project"))
        XCTAssertEqual(
            project.descriptor.entryFilePath,
            main
        )
        XCTAssertEqual(
            project.descriptor.attributes["template"],
            "swift-console"
        )
    }

    func testOpenSessionUsesPersistentProjectWorkspace() throws {
        let (store, root) = try makeStore()
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let model = ProjectBrowserViewModel(
            store: store,
            seedDefaultProject: false
        )

        let descriptor = try model.createProject(
            displayName: "Persistent",
            templateID: "swift-console"
        )

        let session = try model.openSession(
            for: descriptor
        )

        session.source = "print(99)"
        try session.saveActiveFile()

        let reopened = try store.openProject(
            identifier: descriptor.identifier
        )

        XCTAssertEqual(
            try reopened.readTextFile(
                at: WorkspacePath("main.swift")
            ),
            "print(99)"
        )
    }

    func testDeleteProjectRefreshesCatalog() throws {
        let (store, root) = try makeStore()
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let model = ProjectBrowserViewModel(
            store: store,
            seedDefaultProject: false
        )

        let descriptor = try model.createProject(
            displayName: "Delete Me",
            templateID: "empty"
        )

        XCTAssertEqual(model.projects.count, 1)

        try model.deleteProject(descriptor)

        XCTAssertTrue(model.projects.isEmpty)
        XCTAssertFalse(
            try store.projectExists(
                identifier: descriptor.identifier
            )
        )
    }

    func testUnknownTemplateIsRejected() throws {
        let (store, root) = try makeStore()
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let model = ProjectBrowserViewModel(
            store: store,
            seedDefaultProject: false
        )

        XCTAssertThrowsError(
            try model.createProject(
                displayName: "Unknown",
                templateID: "does-not-exist"
            )
        ) { error in
            XCTAssertEqual(
                error as? ProjectBrowserError,
                .templateNotFound("does-not-exist")
            )
        }
    }
}
