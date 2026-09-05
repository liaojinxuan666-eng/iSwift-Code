import Foundation

struct SandboxSwiftCompiler: LocalCompilerBackend {
    let name = "iSwift Sandbox Bytecode"

    func compile(source: String) -> CompileResult {
        var lexer = Lexer(source: source)
        let lexResult = lexer.scanTokens()
        guard lexResult.diagnostics.isEmpty else {
            return CompileResult(program: nil, diagnostics: lexResult.diagnostics)
        }

        var parser = Parser(tokens: lexResult.tokens)
        let parseResult = parser.parse()
        guard parseResult.diagnostics.isEmpty else {
            return CompileResult(program: nil, diagnostics: parseResult.diagnostics)
        }

        var compiler = BytecodeCompiler()
        return compiler.compile(parseResult.statements)
    }

    func run(source: String) -> RunResult {
        let compileResult = compile(source: source)
        guard let program = compileResult.program, compileResult.succeeded else {
            return RunResult(output: "", diagnostics: compileResult.diagnostics, instructionCount: 0)
        }
        return VirtualMachine().execute(program)
    }
}
