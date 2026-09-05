import Foundation
import XCTest
@testable import iSwiftCode

final class ProjectProviderBridgeTests: XCTestCase {
    private func makeSnapshot(
        files: [(String, Data)],
        entryFile: String? = nil
    ) throws -> ProjectWorkspaceSnapshot {
        let descriptor = ProjectDescriptor(
            identifier: "tests.bridge",
            displayName: "Bridge",
            entryFilePath: try entryFile.map(WorkspacePath.init)
        )

        return ProjectWorkspaceSnapshot(
            descriptor: descriptor,
            files: try files.map { item in
                ProjectWorkspaceFile(
                    path: try WorkspacePath(item.0),
                    data: item.1
                )
            }.sorted { $0.path < $1.path }
        )
    }

    func testLanguageResolverIsToolchainAgnostic() throws {
        XCTAssertEqual(
            ProjectSourceLanguageResolver.language(for: try WorkspacePath("main.swift")),
            .swift
        )
        XCTAssertEqual(
            ProjectSourceLanguageResolver.language(for: try WorkspacePath("main.c")),
            .c
        )
        XCTAssertEqual(
            ProjectSourceLanguageResolver.language(for: try WorkspacePath("main.cpp")),
            .cpp
        )
        XCTAssertEqual(
            ProjectSourceLanguageResolver.language(for: try WorkspacePath("main.m")),
            .objectiveC
        )
        XCTAssertEqual(
            ProjectSourceLanguageResolver.language(for: try WorkspacePath("main.mm")),
            .objectiveCpp
        )
        XCTAssertNil(
            ProjectSourceLanguageResolver.language(for: try WorkspacePath("README.md"))
        )
    }

    func testCompilerRequestUsesAllRecognizedSourceFilesAndSkipsResources() throws {
        let snapshot = try makeSnapshot(
            files: [
                ("Sources/main.swift", Data("print(42)".utf8)),
                ("Sources/helper.c", Data("int helper(void) { return 1; }".utf8)),
                ("Resources/config.json", Data("{}".utf8))
            ],
            entryFile: "Sources/main.swift"
        )

        let request = try ProjectProviderBridge.compilerRequest(
            from: snapshot,
            operation: .compile,
            arguments: ["--example"]
        )

        XCTAssertEqual(request.operation, .compile)
        XCTAssertEqual(request.entryFilePath, "Sources/main.swift")
        XCTAssertEqual(request.arguments, ["--example"])
        XCTAssertEqual(request.files.map(\.path), [
            "Sources/helper.c",
            "Sources/main.swift"
        ])
        XCTAssertEqual(request.files.map(\.language), [.c, .swift])
    }

    func testBinarySourceFileIsRejected() throws {
        let snapshot = try makeSnapshot(
            files: [
                ("main.swift", Data([0xFF, 0xFE, 0xFD]))
            ],
            entryFile: "main.swift"
        )

        XCTAssertThrowsError(
            try ProjectProviderBridge.compilerRequest(
                from: snapshot,
                operation: .run
            )
        ) { error in
            XCTAssertEqual(
                error as? ProjectProviderBridgeError,
                .sourceFileIsNotUTF8(try! WorkspacePath("main.swift"))
            )
        }
    }

    func testResourceOnlyProjectHasNoCompilerSources() throws {
        let snapshot = try makeSnapshot(
            files: [
                ("README.md", Data("# Project".utf8)),
                ("Resources/icon.txt", Data("icon".utf8))
            ]
        )

        XCTAssertThrowsError(
            try ProjectProviderBridge.compilerRequest(
                from: snapshot,
                operation: .check
            )
        ) { error in
            XCTAssertEqual(error as? ProjectProviderBridgeError, .noSourceFiles)
        }
    }

    func testEntryFileMustBeCompilerSource() throws {
        let snapshot = try makeSnapshot(
            files: [
                ("Sources/main.swift", Data("print(42)".utf8)),
                ("README.md", Data("# Project".utf8))
            ],
            entryFile: "README.md"
        )

        XCTAssertThrowsError(
            try ProjectProviderBridge.compilerRequest(
                from: snapshot,
                operation: .run
            )
        ) { error in
            XCTAssertEqual(
                error as? ProjectProviderBridgeError,
                .entryFileIsNotSource(try! WorkspacePath("README.md"))
            )
        }
    }

    func testAIRequestReceivesTextWorkspaceSnapshotButNotBinaryFiles() throws {
        let snapshot = try makeSnapshot(
            files: [
                ("Sources/main.swift", Data("print(42)".utf8)),
                ("README.md", Data("# Hello".utf8)),
                ("Resources/blob.bin", Data([0xFF, 0xFE]))
            ]
        )

        let request = ProjectProviderBridge.aiRequest(
            from: snapshot,
            task: .reviewWorkspace,
            messages: [
                AIMessage(role: .user, content: "Review this project")
            ]
        )

        XCTAssertEqual(request.task, .reviewWorkspace)
        XCTAssertEqual(request.workspaceFiles.map(\.path), [
            "README.md",
            "Sources/main.swift"
        ])
        XCTAssertEqual(request.messages.count, 1)
    }

    func testScratchWorkspaceCanRunThroughBridgeAndSandboxProvider() throws {
        let mainPath = try WorkspacePath("main.swift")
        let storage = InMemoryProjectWorkspaceStorage()
        let workspace = try ProjectWorkspace(
            descriptor: ProjectDescriptor(
                identifier: "tests.scratch",
                displayName: "Scratch",
                entryFilePath: mainPath
            ),
            storage: storage
        )

        try workspace.writeTextFile("print(40 + 2)", at: mainPath)

        let request = try ProjectProviderBridge.compilerRequest(
            from: workspace.snapshot(),
            operation: .run
        )

        let result = try SandboxSwiftCompilerProvider().perform(request)

        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(result.output.trimmingCharacters(in: .whitespacesAndNewlines), "42")
    }

    func testInMemoryStorageSupportsWorkspaceMutation() throws {
        let storage = InMemoryProjectWorkspaceStorage()
        let descriptor = ProjectDescriptor(
            identifier: "tests.memory",
            displayName: "Memory"
        )
        let workspace = try ProjectWorkspace(
            descriptor: descriptor,
            storage: storage
        )

        let first = try WorkspacePath("Sources/a.swift")
        let second = try WorkspacePath("Sources/b.swift")

        try workspace.writeTextFile("let a = 1", at: first)
        try workspace.moveFile(from: first, to: second)

        XCTAssertEqual(try workspace.listFiles(), [second])
        XCTAssertEqual(try workspace.readTextFile(at: second), "let a = 1")

        try workspace.deleteFile(at: second)
        XCTAssertEqual(try workspace.listFiles(), [])
    }
}
