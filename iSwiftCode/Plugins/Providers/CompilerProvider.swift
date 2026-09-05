import Foundation

enum CompilerLanguage: String, Codable, CaseIterable, Hashable, Sendable {
    case swift
    case c
    case cpp = "c++"
    case objectiveC = "objective-c"
    case objectiveCpp = "objective-c++"
}

enum CompilerOperation: String, Codable, CaseIterable, Hashable, Sendable {
    case check
    case compile
    case run
}

struct CompilerSourceFile: Codable, Equatable, Hashable, Sendable {
    let path: String
    let contents: String
    let language: CompilerLanguage
}

struct CompilerRequest: Equatable, Sendable {
    let operation: CompilerOperation
    let files: [CompilerSourceFile]
    let entryFilePath: String?
    let arguments: [String]

    init(
        operation: CompilerOperation,
        files: [CompilerSourceFile],
        entryFilePath: String? = nil,
        arguments: [String] = []
    ) {
        self.operation = operation
        self.files = files
        self.entryFilePath = entryFilePath
        self.arguments = arguments
    }

    static func singleFile(
        operation: CompilerOperation,
        language: CompilerLanguage,
        path: String,
        source: String,
        arguments: [String] = []
    ) -> CompilerRequest {
        CompilerRequest(
            operation: operation,
            files: [CompilerSourceFile(path: path, contents: source, language: language)],
            entryFilePath: path,
            arguments: arguments
        )
    }
}

enum CompilerArtifactKind: String, Codable, CaseIterable, Hashable, Sendable {
    case objectFile
    case executable
    case wasmModule
    case appBundle
    case ipa
    case textualIR
    case other
}

struct CompilerArtifact: Equatable, Sendable {
    let name: String
    let kind: CompilerArtifactKind
    let data: Data?

    init(name: String, kind: CompilerArtifactKind, data: Data? = nil) {
        self.name = name
        self.kind = kind
        self.data = data
    }
}

struct CompilerMetrics: Equatable, Sendable {
    let instructionCount: Int?
    let durationMilliseconds: Int?

    init(instructionCount: Int? = nil, durationMilliseconds: Int? = nil) {
        self.instructionCount = instructionCount
        self.durationMilliseconds = durationMilliseconds
    }
}

struct CompilerProviderResult: Sendable {
    let output: String
    let diagnostics: [CompilerDiagnostic]
    let artifacts: [CompilerArtifact]
    let metrics: CompilerMetrics

    init(
        output: String = "",
        diagnostics: [CompilerDiagnostic] = [],
        artifacts: [CompilerArtifact] = [],
        metrics: CompilerMetrics = CompilerMetrics()
    ) {
        self.output = output
        self.diagnostics = diagnostics
        self.artifacts = artifacts
        self.metrics = metrics
    }

    var succeeded: Bool {
        !diagnostics.contains(where: { $0.severity == .error })
    }
}

enum CompilerProviderError: Error, Equatable, Sendable {
    case unsupportedLanguage(CompilerLanguage)
    case unsupportedOperation(CompilerOperation)
    case invalidRequest(String)
}

extension CompilerProviderError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .unsupportedLanguage(let language):
            return "Compiler provider does not support language '\(language.rawValue)'."
        case .unsupportedOperation(let operation):
            return "Compiler provider does not support operation '\(operation.rawValue)'."
        case .invalidRequest(let message):
            return message
        }
    }
}

protocol CompilerProvider: ISwiftPlugin {
    var providerName: String { get }
    var supportedLanguages: Set<CompilerLanguage> { get }
    var supportedOperations: Set<CompilerOperation> { get }

    func perform(_ request: CompilerRequest) throws -> CompilerProviderResult
}
