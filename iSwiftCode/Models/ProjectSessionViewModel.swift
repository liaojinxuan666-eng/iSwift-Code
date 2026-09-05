import Foundation
import Combine

enum ProjectSessionError: Error, Equatable, Sendable {
    case fileAlreadyExists(WorkspacePath)
    case fileNotFound(WorkspacePath)
    case fileIsNotUTF8(WorkspacePath)
    case cannotModifyEntryFile(WorkspacePath)
    case noActiveFile
}

extension ProjectSessionError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .fileAlreadyExists(let path):
            return "A file already exists at '\(path.value)'."
        case .fileNotFound(let path):
            return "File '\(path.value)' does not exist."
        case .fileIsNotUTF8(let path):
            return "File '\(path.value)' cannot be opened in the text editor."
        case .cannotModifyEntryFile(let path):
            return "The project entry file '\(path.value)' cannot be renamed or deleted yet."
        case .noActiveFile:
            return "No file is currently selected."
        }
    }
}

/// Main project editing session.
///
/// The session owns editor buffers and UI state, while `ProjectWorkspace`
/// remains the source of persisted project data. Compiler and AI providers
/// receive snapshots produced from this same session.
@MainActor
final class ProjectSessionViewModel: ObservableObject {
    @Published private(set) var files: [WorkspacePath] = []
    @Published private(set) var activeFilePath: WorkspacePath?
    @Published var source: String {
        didSet {
            guard !isReplacingSource, let activeFilePath else { return }
            buffers[activeFilePath] = source
            dirtyFilePaths.insert(activeFilePath)
        }
    }

    @Published private(set) var dirtyFilePaths: Set<WorkspacePath> = []
    @Published private(set) var consoleOutput = "Tap Run to compile locally."
    @Published private(set) var diagnostics: [CompilerDiagnostic] = []
    @Published private(set) var buildSummary = "Ready"
    @Published private(set) var isRunning = false
    @Published var errorMessage: String?

    private let compiler: any CompilerProvider
    private var workspace: ProjectWorkspace
    private var buffers: [WorkspacePath: String] = [:]
    private var isReplacingSource = false

    var projectName: String {
        workspace.descriptor.displayName
    }

    var entryFilePath: WorkspacePath? {
        workspace.descriptor.entryFilePath
    }

    var activeFileName: String {
        activeFilePath?.fileName ?? "No File"
    }

    var isActiveFileDirty: Bool {
        guard let activeFilePath else { return false }
        return dirtyFilePaths.contains(activeFilePath)
    }

    init(compiler: any CompilerProvider = SandboxSwiftCompilerProvider()) {
        self.compiler = compiler

        let mainPath = try! WorkspacePath("main.swift")
        let storage = InMemoryProjectWorkspaceStorage()
        let descriptor = ProjectDescriptor(
            identifier: "iswift.scratch",
            displayName: "Scratch Project",
            entryFilePath: mainPath
        )
        let workspace = try! ProjectWorkspace(
            descriptor: descriptor,
            storage: storage
        )

        self.workspace = workspace
        self.activeFilePath = mainPath
        self.source = Self.welcomeProgram

        try? workspace.writeTextFile(Self.welcomeProgram, at: mainPath)
        self.files = [mainPath]
        self.buffers[mainPath] = Self.welcomeProgram
    }

    init(
        compiler: any CompilerProvider,
        workspace: ProjectWorkspace,
        preferredActiveFile: WorkspacePath? = nil
    ) throws {
        self.compiler = compiler
        self.workspace = workspace
        self.source = ""

        try reloadFiles()

        let candidate =
            preferredActiveFile ??
            workspace.descriptor.entryFilePath ??
            files.first

        if let candidate {
            try selectFile(candidate)
        }
    }

    func reloadFiles() throws {
        files = try workspace.listFiles().sorted()

        if let activeFilePath, !files.contains(activeFilePath) {
            self.activeFilePath = nil
            replaceSource("")
        }
    }

    func selectFile(_ path: WorkspacePath) throws {
        guard try workspace.contains(path) else {
            throw ProjectSessionError.fileNotFound(path)
        }

        let text: String
        if let buffered = buffers[path] {
            text = buffered
        } else {
            let data = try workspace.readFile(at: path)
            guard let decoded = String(data: data, encoding: .utf8) else {
                throw ProjectSessionError.fileIsNotUTF8(path)
            }
            text = decoded
            buffers[path] = decoded
        }

        activeFilePath = path
        replaceSource(text)
    }

    func createFile(at path: WorkspacePath, contents: String = "") throws {
        guard !(try workspace.contains(path)) else {
            throw ProjectSessionError.fileAlreadyExists(path)
        }

        try workspace.writeTextFile(contents, at: path)
        buffers[path] = contents
        try reloadFiles()
        try selectFile(path)
    }

    func renameFile(from sourcePath: WorkspacePath, to destinationPath: WorkspacePath) throws {
        if sourcePath == workspace.descriptor.entryFilePath {
            throw ProjectSessionError.cannotModifyEntryFile(sourcePath)
        }
        guard try workspace.contains(sourcePath) else {
            throw ProjectSessionError.fileNotFound(sourcePath)
        }
        guard !(try workspace.contains(destinationPath)) else {
            throw ProjectSessionError.fileAlreadyExists(destinationPath)
        }

        try workspace.moveFile(from: sourcePath, to: destinationPath)

        if let buffered = buffers.removeValue(forKey: sourcePath) {
            buffers[destinationPath] = buffered
        }

        if dirtyFilePaths.remove(sourcePath) != nil {
            dirtyFilePaths.insert(destinationPath)
        }

        if activeFilePath == sourcePath {
            activeFilePath = destinationPath
        }

        try reloadFiles()

        if activeFilePath == destinationPath {
            let text = buffers[destinationPath] ?? (try workspace.readTextFile(at: destinationPath))
            buffers[destinationPath] = text
            replaceSource(text)
        }
    }

    func deleteFile(at path: WorkspacePath) throws {
        if path == workspace.descriptor.entryFilePath {
            throw ProjectSessionError.cannotModifyEntryFile(path)
        }
        guard try workspace.contains(path) else {
            throw ProjectSessionError.fileNotFound(path)
        }

        try workspace.deleteFile(at: path)
        buffers.removeValue(forKey: path)
        dirtyFilePaths.remove(path)

        let wasActive = activeFilePath == path
        try reloadFiles()

        if wasActive {
            let next = workspace.descriptor.entryFilePath.flatMap { entry in
                files.contains(entry) ? entry : nil
            } ?? files.first

            if let next {
                try selectFile(next)
            } else {
                activeFilePath = nil
                replaceSource("")
            }
        }
    }

    func saveActiveFile() throws {
        guard let activeFilePath else {
            throw ProjectSessionError.noActiveFile
        }

        let text = buffers[activeFilePath] ?? source
        try workspace.writeTextFile(text, at: activeFilePath)
        dirtyFilePaths.remove(activeFilePath)
    }

    func saveAll() throws {
        for path in dirtyFilePaths.sorted() {
            guard let text = buffers[path] else { continue }
            try workspace.writeTextFile(text, at: path)
        }
        dirtyFilePaths.removeAll()
    }

    func snapshotIncludingUnsavedChanges() throws -> ProjectWorkspaceSnapshot {
        let persisted = try workspace.snapshot()

        let files = persisted.files.map { file -> ProjectWorkspaceFile in
            guard let buffered = buffers[file.path] else {
                return file
            }
            return ProjectWorkspaceFile(
                path: file.path,
                data: Data(buffered.utf8)
            )
        }

        return ProjectWorkspaceSnapshot(
            descriptor: persisted.descriptor,
            files: files.sorted { $0.path < $1.path }
        )
    }

    func run() {
        isRunning = true
        diagnostics = []
        buildSummary = "Compiling locally…"

        do {
            let snapshot = try snapshotIncludingUnsavedChanges()
            let request = try ProjectProviderBridge.compilerRequest(
                from: snapshot,
                operation: .run
            )
            let result = try compiler.perform(request)

            diagnostics = result.diagnostics

            if result.succeeded {
                consoleOutput = result.output.isEmpty
                    ? "Program finished with no output."
                    : result.output

                var details: [String] = ["Succeeded"]
                if let instructionCount = result.metrics.instructionCount {
                    details.append("\(instructionCount) instructions")
                }
                if let durationMilliseconds = result.metrics.durationMilliseconds {
                    details.append("\(durationMilliseconds) ms")
                }
                buildSummary = details.joined(separator: " • ")
            } else {
                consoleOutput = result.output.isEmpty
                    ? "Compilation stopped."
                    : result.output
                buildSummary = "Failed with \(result.diagnostics.count) error(s)"
            }
        } catch {
            diagnostics = [
                CompilerDiagnostic(
                    severity: .error,
                    message: error.localizedDescription,
                    location: .start
                )
            ]
            consoleOutput = "Compilation stopped."
            buildSummary = "Compiler provider failed"
        }

        isRunning = false
    }

    func restoreExample() {
        guard let entryFilePath = workspace.descriptor.entryFilePath else {
            errorMessage = ProjectSessionError.noActiveFile.localizedDescription
            return
        }

        do {
            if !(try workspace.contains(entryFilePath)) {
                try workspace.writeTextFile(Self.welcomeProgram, at: entryFilePath)
                try reloadFiles()
            }

            buffers[entryFilePath] = Self.welcomeProgram
            dirtyFilePaths.insert(entryFilePath)
            try selectFile(entryFilePath)

            consoleOutput = "Example restored."
            diagnostics = []
            buildSummary = "Ready"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func present(error: Error) {
        errorMessage = error.localizedDescription
    }

    func clearError() {
        errorMessage = nil
    }

    private func replaceSource(_ text: String) {
        isReplacingSource = true
        source = text
        isReplacingSource = false
    }

    static let welcomeProgram = """
    let appName = "iSwift Code"
    var answer = 40
    answer = answer + 2

    print(appName)
    print(answer)

    if answer == 42 {
        print("Local compilation works!")
    } else {
        print("Try again")
    }
    """
}
