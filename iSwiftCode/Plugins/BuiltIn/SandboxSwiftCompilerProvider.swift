import Foundation

final class SandboxSwiftCompilerProvider: CompilerProvider {
    let manifest = PluginManifest(
        identifier: "com.iswiftcode.compiler.sandbox-swift",
        displayName: "iSwift Sandbox Swift",
        version: "0.1.2",
        capabilities: [.compiler],
        executionMode: .builtIn
    )

    let providerName = "iSwift Sandbox Bytecode"
    let supportedLanguages: Set<CompilerLanguage> = [.swift]
    let supportedOperations: Set<CompilerOperation> = [.check, .compile, .run]

    private let compiler: SandboxSwiftCompiler

    init(compiler: SandboxSwiftCompiler = SandboxSwiftCompiler()) {
        self.compiler = compiler
    }

    func perform(_ request: CompilerRequest) throws -> CompilerProviderResult {
        guard supportedOperations.contains(request.operation) else {
            throw CompilerProviderError.unsupportedOperation(request.operation)
        }

        guard request.files.count == 1, let file = request.files.first else {
            throw CompilerProviderError.invalidRequest(
                "The sandbox Swift provider currently supports exactly one source file."
            )
        }

        guard supportedLanguages.contains(file.language) else {
            throw CompilerProviderError.unsupportedLanguage(file.language)
        }

        if let entryFilePath = request.entryFilePath, entryFilePath != file.path {
            throw CompilerProviderError.invalidRequest(
                "The entry file must match the single source file used by the sandbox provider."
            )
        }

        let started = Date()

        switch request.operation {
        case .check, .compile:
            let result = compiler.compile(source: file.contents)
            return CompilerProviderResult(
                diagnostics: result.diagnostics,
                metrics: CompilerMetrics(
                    durationMilliseconds: Self.elapsedMilliseconds(since: started)
                )
            )

        case .run:
            let result = compiler.run(source: file.contents)
            return CompilerProviderResult(
                output: result.output,
                diagnostics: result.diagnostics,
                metrics: CompilerMetrics(
                    instructionCount: result.instructionCount,
                    durationMilliseconds: Self.elapsedMilliseconds(since: started)
                )
            )
        }
    }

    private static func elapsedMilliseconds(since start: Date) -> Int {
        Int(Date().timeIntervalSince(start) * 1_000)
    }
}
