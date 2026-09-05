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

    init(compiler: any CompilerProvider = SandboxSwiftCompilerProvider()) {
        self.compiler = compiler
        source = Self.welcomeProgram
    }

    func run() {
        isRunning = true
        diagnostics = []
        buildSummary = "Compiling locally…"

        let request = CompilerRequest.singleFile(
            operation: .run,
            language: .swift,
            path: "main.swift",
            source: source
        )

        do {
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
