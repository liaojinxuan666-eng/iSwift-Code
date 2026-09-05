import Foundation

struct SourceLocation: Equatable, Sendable {
    let line: Int
    let column: Int

    static let start = SourceLocation(line: 1, column: 1)
}

struct CompilerDiagnostic: Identifiable, Equatable, Sendable {
    enum Severity: String, Sendable {
        case error
        case warning
    }

    let id = UUID()
    let severity: Severity
    let message: String
    let location: SourceLocation

    static func == (lhs: CompilerDiagnostic, rhs: CompilerDiagnostic) -> Bool {
        lhs.severity == rhs.severity &&
        lhs.message == rhs.message &&
        lhs.location == rhs.location
    }
}

enum RuntimeValue: Equatable, Sendable {
    case int(Int)
    case double(Double)
    case string(String)
    case bool(Bool)
    case void

    var displayText: String {
        switch self {
        case .int(let value):
            return String(value)
        case .double(let value):
            return value.rounded() == value ? String(format: "%.1f", value) : String(value)
        case .string(let value):
            return value
        case .bool(let value):
            return value ? "true" : "false"
        case .void:
            return "()"
        }
    }

    var typeName: String {
        switch self {
        case .int: return "Int"
        case .double: return "Double"
        case .string: return "String"
        case .bool: return "Bool"
        case .void: return "Void"
        }
    }
}

struct CompileResult: Sendable {
    let program: BytecodeProgram?
    let diagnostics: [CompilerDiagnostic]

    var succeeded: Bool {
        program != nil && !diagnostics.contains(where: { $0.severity == .error })
    }
}

struct RunResult: Sendable {
    let output: String
    let diagnostics: [CompilerDiagnostic]
    let instructionCount: Int

    var succeeded: Bool {
        !diagnostics.contains(where: { $0.severity == .error })
    }
}

protocol LocalCompilerBackend: Sendable {
    var name: String { get }
    func compile(source: String) -> CompileResult
    func run(source: String) -> RunResult
}
