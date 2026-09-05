import Foundation
import Combine

@MainActor
final class EditorViewModel: ObservableObject {
    @Published var source: String
    @Published private(set) var consoleOutput = "Tap Run to compile locally."
    @Published private(set) var diagnostics: [CompilerDiagnostic] = []
    @Published private(set) var buildSummary = "Ready"
    @Published private(set) var isRunning = false

    private let compiler: any CompilerProvider
    private let workspace: ProjectWorkspace
    private let activeFilePath: WorkspacePath

    init(compiler: any CompilerProvider = SandboxSwiftCompilerProvider()) {
        self.compiler = compiler

        // These literals are controlled by the application and are validated
        // once when the default scratch project is constructed.
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
    }

    /// Dependency-injection initializer used by the future project UI and tests.
    init(
        compiler: any CompilerProvider,
        workspace: ProjectWorkspace,
        activeFilePath: WorkspacePath
    ) {
        self.compiler = compiler
        self.workspace = workspace
        self.activeFilePath = activeFilePath
        self.source = (try? workspace.readTextFile(at: activeFilePath)) ?? ""
    }

    func run() {
        isRunning = true
        diagnostics = []
        buildSummary = "Compiling locally…"

        do {
            // The editor writes through ProjectWorkspace first. Compiler
            // providers therefore consume the same project state that plugins
            // and future AI providers see.
            try workspace.writeTextFile(source, at: activeFilePath)

            let snapshot = try workspace.snapshot()
            let request = try ProjectProviderBridge.compilerRequest(
                from: snapshot,
                operation: .run
            )

            let result = try compiler.perform(request)
            diagnostics = result.diagnostics

            if result.succeeded {
                consoleOutput = result.output.isEmpty ? "Program finished with no output." : result.output

                var details: [String] = ["Succeeded"]
                if let instructionCount = result.metrics.instructionCount {
                    details.append("\(instructionCount) instructions")
                }
                if let durationMilliseconds = result.metrics.durationMilliseconds {
                    details.append("\(durationMilliseconds) ms")
                }
                buildSummary = details.joined(separator: " • ")
            } else {
                consoleOutput = result.output.isEmpty ? "Compilation stopped." : result.output
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
        source = Self.welcomeProgram
        try? workspace.writeTextFile(Self.welcomeProgram, at: activeFilePath)
        consoleOutput = "Example restored."
        diagnostics = []
        buildSummary = "Ready"
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
