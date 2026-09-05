import Foundation
import Combine

@MainActor
final class EditorViewModel: ObservableObject {
    @Published var source: String
    @Published private(set) var consoleOutput = "Tap Run to compile locally."
    @Published private(set) var diagnostics: [CompilerDiagnostic] = []
    @Published private(set) var buildSummary = "Ready"
    @Published private(set) var isRunning = false

    private let compiler: any LocalCompilerBackend

    init(compiler: any LocalCompilerBackend = SandboxSwiftCompiler()) {
        self.compiler = compiler
        source = Self.welcomeProgram
    }

    func run() {
        isRunning = true
        diagnostics = []
        buildSummary = "Compiling locally…"

        let started = Date()
        let result = compiler.run(source: source)
        let elapsedMilliseconds = Int(Date().timeIntervalSince(started) * 1_000)

        diagnostics = result.diagnostics
        if result.succeeded {
            consoleOutput = result.output.isEmpty ? "Program finished with no output." : result.output
            buildSummary = "Succeeded • \(result.instructionCount) instructions • \(elapsedMilliseconds) ms"
        } else {
            consoleOutput = result.output.isEmpty ? "Compilation stopped." : result.output
            buildSummary = "Failed with \(result.diagnostics.count) error(s)"
        }
        isRunning = false
    }

    func restoreExample() {
        source = Self.welcomeProgram
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
