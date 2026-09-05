import Foundation
import XCTest
@testable import iSwiftCode

final class ProjectWorkspaceTests: XCTestCase {
    private final class MemoryStorage: ProjectWorkspaceStorage, @unchecked Sendable {
        private let lock = NSLock()
        private var files: [WorkspacePath: Data]

        init(files: [WorkspacePath: Data] = [:]) {
            self.files = files
        }

        func listFiles() throws -> [WorkspacePath] {
            lock.lock()
            defer { lock.unlock() }
            return files.keys.sorted()
        }

        func readFile(at path: WorkspacePath) throws -> Data {
            lock.lock()
            defer { lock.unlock() }

            guard let data = files[path] else {
                throw CocoaError(.fileNoSuchFile)
            }
            return data
        }

        func writeFile(_ data: Data, at path: WorkspacePath) throws {
            lock.lock()
            defer { lock.unlock() }
            files[path] = data
        }

        func deleteFile(at path: WorkspacePath) throws {
            lock.lock()
            defer { lock.unlock() }

            guard files.removeValue(forKey: path) != nil else {
                throw CocoaError(.fileNoSuchFile)
            }
        }

        func moveFile(from sourcePath: WorkspacePath, to destinationPath: WorkspacePath) throws {
            lock.lock()
            defer { lock.unlock() }

            guard let data = files.removeValue(forKey: sourcePath) else {
                throw CocoaError(.fileNoSuchFile)
            }
            files[destinationPath] = data
        }
    }

    private func makeWorkspace(
        entryFilePath: String? = "Sources/main.swift",
        storage: MemoryStorage = MemoryStorage()
    ) throws -> ProjectWorkspace {
        let entryPath = try entryFilePath.map(WorkspacePath.init)

        return try ProjectWorkspace(
            descriptor: ProjectDescriptor(
                identifier: "tests.workspace",
                displayName: "Workspace Test",
                entryFilePath: entryPath
            ),
            storage: storage
        )
    }

    func testWorkspacePathRejectsTraversalAndAbsolutePaths() {
        XCTAssertThrowsError(try WorkspacePath("../secret"))
        XCTAssertThrowsError(try WorkspacePath("Sources/../secret"))
        XCTAssertThrowsError(try WorkspacePath("/private/file"))
        XCTAssertThrowsError(try WorkspacePath("Sources\\main.swift"))
        XCTAssertThrowsError(try WorkspacePath("Sources//main.swift"))
    }

    func testWorkspacePathCodableUsesPlainString() throws {
        let path = try WorkspacePath("Sources/main.swift")
        let data = try JSONEncoder().encode(path)

        // JSONEncoder may legally escape "/" as "\/" depending on Foundation
        // behavior. Decode the JSON string instead of asserting raw bytes.
        let encodedString = try JSONDecoder().decode(String.self, from: data)
        XCTAssertEqual(encodedString, path.value)

        let decoded = try JSONDecoder().decode(WorkspacePath.self, from: data)
        XCTAssertEqual(decoded, path)
    }

    func testDescriptorRoundTrip() throws {
        let descriptor = ProjectDescriptor(
            identifier: "com.example.project",
            displayName: "Example",
            entryFilePath: try WorkspacePath("Sources/main.swift"),
            attributes: ["toolchain": "default"]
        )

        let data = try JSONEncoder().encode(descriptor)
        let decoded = try JSONDecoder().decode(ProjectDescriptor.self, from: data)

        XCTAssertEqual(decoded, descriptor)
        XCTAssertNoThrow(try decoded.validate())
    }

    func testReadWriteMoveDeleteAndList() throws {
        let workspace = try makeWorkspace()
        let source = try WorkspacePath("Sources/main.swift")
        let helper = try WorkspacePath("Sources/Helper.swift")

        try workspace.writeTextFile("print(42)", at: source)
        try workspace.writeTextFile("let helper = true", at: helper)

        XCTAssertEqual(
            try workspace.listFiles().map(\.value),
            ["Sources/Helper.swift", "Sources/main.swift"]
        )
        XCTAssertEqual(try workspace.readTextFile(at: source), "print(42)")

        let moved = try WorkspacePath("Sources/Support/Helper.swift")
        try workspace.moveFile(from: helper, to: moved)

        XCTAssertFalse(try workspace.contains(helper))
        XCTAssertTrue(try workspace.contains(moved))

        try workspace.deleteFile(at: moved)
        XCTAssertFalse(try workspace.contains(moved))
    }

    func testEntryFileAndSnapshot() throws {
        let workspace = try makeWorkspace()
        let entry = try WorkspacePath("Sources/main.swift")
        let resource = try WorkspacePath("Resources/config.json")

        try workspace.writeTextFile("print(42)", at: entry)
        try workspace.writeTextFile("{\"enabled\":true}", at: resource)

        let entryFile = try workspace.entryFile()
        XCTAssertEqual(entryFile.path, entry)
        XCTAssertEqual(entryFile.text, "print(42)")

        let snapshot = try workspace.snapshot()
        XCTAssertEqual(snapshot.files.map(\.path.value), [
            "Resources/config.json",
            "Sources/main.swift"
        ])
        XCTAssertEqual(snapshot.file(at: resource)?.text, "{\"enabled\":true}")
    }

    func testMissingEntryFileIsReported() throws {
        let workspace = try makeWorkspace()

        XCTAssertThrowsError(try workspace.entryFile()) { error in
            XCTAssertEqual(
                error as? ProjectWorkspaceError,
                .entryFileMissing(try! WorkspacePath("Sources/main.swift"))
            )
        }
    }

    func testPluginBackendUsesSameWorkspace() throws {
        let workspace = try makeWorkspace(entryFilePath: nil)
        let backend = ProjectWorkspacePluginBackend(workspace: workspace)

        try backend.writeFile(Data("hello".utf8), at: "Notes/readme.txt")

        XCTAssertEqual(try backend.listFiles(), ["Notes/readme.txt"])
        XCTAssertEqual(
            String(data: try backend.readFile(at: "Notes/readme.txt"), encoding: .utf8),
            "hello"
        )

        try backend.moveFile(
            from: "Notes/readme.txt",
            to: "Docs/readme.txt"
        )

        XCTAssertEqual(try backend.listFiles(), ["Docs/readme.txt"])

        try backend.deleteFile(at: "Docs/readme.txt")
        XCTAssertEqual(try backend.listFiles(), [])
    }

    func testPluginBackendRejectsTraversal() throws {
        let workspace = try makeWorkspace(entryFilePath: nil)
        let backend = ProjectWorkspacePluginBackend(workspace: workspace)

        XCTAssertThrowsError(
            try backend.writeFile(Data(), at: "../escape")
        )
    }

    func testDirectoryStorageStaysInsideRoot() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let storage = try DirectoryProjectWorkspaceStorage(rootURL: root)
        let workspace = try ProjectWorkspace(
            descriptor: ProjectDescriptor(
                identifier: "tests.directory",
                displayName: "Directory Storage"
            ),
            storage: storage
        )

        let path = try WorkspacePath("Sources/main.swift")
        try workspace.writeTextFile("print(42)", at: path)

        XCTAssertEqual(try workspace.readTextFile(at: path), "print(42)")
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: root.appendingPathComponent("Sources/main.swift").path
            )
        )
    }
}
