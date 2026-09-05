import Foundation

enum OpCode: Sendable {
    case push(RuntimeValue)
    case load(String)
    case declare(name: String, mutable: Bool)
    case assign(String)
    case add
    case subtract
    case multiply
    case divide
    case negate
    case not
    case equal
    case notEqual
    case less
    case lessEqual
    case greater
    case greaterEqual
    case and
    case or
    case print
    case pop
    case jumpIfFalse(Int)
    case jump(Int)
}

struct BytecodeInstruction: Sendable {
    let operation: OpCode
    let location: SourceLocation
}

struct BytecodeProgram: Sendable {
    let instructions: [BytecodeInstruction]
}

struct BytecodeCompiler {
    private var instructions: [BytecodeInstruction] = []
    private var diagnostics: [CompilerDiagnostic] = []

    mutating func compile(_ statements: [Statement]) -> CompileResult {
        statements.forEach { compile(statement: $0) }
        let program = diagnostics.contains(where: { $0.severity == .error })
            ? nil
            : BytecodeProgram(instructions: instructions)
        return CompileResult(program: program, diagnostics: diagnostics)
    }

    private mutating func compile(statement: Statement) {
        switch statement {
        case .declaration(let name, let mutable, let initializer, let location):
            compile(expression: initializer)
            emit(.declare(name: name, mutable: mutable), at: location)
        case .assignment(let name, let value, let location):
            compile(expression: value)
            emit(.assign(name), at: location)
        case .print(let expression, let location):
            compile(expression: expression)
            emit(.print, at: location)
        case .expression(let expression, let location):
            compile(expression: expression)
            emit(.pop, at: location)
        case .ifStatement(let condition, let thenBranch, let elseBranch, let location):
            compile(expression: condition)
            let falseJump = emitPlaceholder(.jumpIfFalse(-1), at: location)
            thenBranch.forEach { compile(statement: $0) }

            if elseBranch.isEmpty {
                patchJump(at: falseJump, to: instructions.count, conditional: true)
            } else {
                let endJump = emitPlaceholder(.jump(-1), at: location)
                patchJump(at: falseJump, to: instructions.count, conditional: true)
                elseBranch.forEach { compile(statement: $0) }
                patchJump(at: endJump, to: instructions.count, conditional: false)
            }
        }
    }

    private mutating func compile(expression: Expression) {
        switch expression {
        case .literal(let value, let location):
            emit(.push(value), at: location)
        case .variable(let name, let location):
            emit(.load(name), at: location)
        case .unary(let operation, let operand, let location):
            compile(expression: operand)
            switch operation {
            case .minus: emit(.negate, at: location)
            case .bang: emit(.not, at: location)
            default: report("Unsupported unary operator.", at: location)
            }
        case .binary(let lhs, let operation, let rhs, let location):
            compile(expression: lhs)
            compile(expression: rhs)
            switch operation {
            case .plus: emit(.add, at: location)
            case .minus: emit(.subtract, at: location)
            case .star: emit(.multiply, at: location)
            case .slash: emit(.divide, at: location)
            case .equalEqual: emit(.equal, at: location)
            case .bangEqual: emit(.notEqual, at: location)
            case .less: emit(.less, at: location)
            case .lessEqual: emit(.lessEqual, at: location)
            case .greater: emit(.greater, at: location)
            case .greaterEqual: emit(.greaterEqual, at: location)
            case .andAnd: emit(.and, at: location)
            case .orOr: emit(.or, at: location)
            default: report("Unsupported binary operator.", at: location)
            }
        }
    }

    private mutating func emit(_ operation: OpCode, at location: SourceLocation) {
        instructions.append(BytecodeInstruction(operation: operation, location: location))
    }

    private mutating func emitPlaceholder(_ operation: OpCode, at location: SourceLocation) -> Int {
        let index = instructions.count
        emit(operation, at: location)
        return index
    }

    private mutating func patchJump(at index: Int, to target: Int, conditional: Bool) {
        let location = instructions[index].location
        instructions[index] = BytecodeInstruction(
            operation: conditional ? .jumpIfFalse(target) : .jump(target),
            location: location
        )
    }

    private mutating func report(_ message: String, at location: SourceLocation) {
        diagnostics.append(CompilerDiagnostic(severity: .error, message: message, location: location))
    }
}
