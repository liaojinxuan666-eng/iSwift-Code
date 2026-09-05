import Foundation

enum OpCode: Sendable {
    case push(RuntimeValue)
    case load(String)
    case declare(name: String, mutable: Bool)
    case assign(String)
    case beginScope
    case endScope
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

private struct LoopContext {
    let conditionTarget: Int
    let scopeDepthAtEntry: Int
    var breakJumps: [Int]
}

struct BytecodeCompiler {
    private var instructions: [BytecodeInstruction] = []
    private var diagnostics: [CompilerDiagnostic] = []
    private var scopeDepth = 0
    private var loops: [LoopContext] = []

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

        case .block(let statements, let location):
            compileScoped(statements, at: location)

        case .ifStatement(let condition, let thenBranch, let elseBranch, let location):
            compile(expression: condition)
            let falseJump = emitPlaceholder(.jumpIfFalse(-1), at: location)
            compileScoped(thenBranch, at: location)

            if elseBranch.isEmpty {
                patchJump(at: falseJump, to: instructions.count, conditional: true)
            } else {
                let endJump = emitPlaceholder(.jump(-1), at: location)
                patchJump(at: falseJump, to: instructions.count, conditional: true)
                compileScoped(elseBranch, at: location)
                patchJump(at: endJump, to: instructions.count, conditional: false)
            }

        case .whileStatement(let condition, let body, let location):
            let conditionTarget = instructions.count
            compile(expression: condition)
            let exitJump = emitPlaceholder(.jumpIfFalse(-1), at: location)

            loops.append(
                LoopContext(
                    conditionTarget: conditionTarget,
                    scopeDepthAtEntry: scopeDepth,
                    breakJumps: []
                )
            )

            compileScoped(body, at: location)
            emit(.jump(conditionTarget), at: location)

            let loopEnd = instructions.count
            patchJump(at: exitJump, to: loopEnd, conditional: true)

            guard let finishedLoop = loops.popLast() else {
                report("Internal loop compiler error.", at: location)
                return
            }
            for breakJump in finishedLoop.breakJumps {
                patchJump(at: breakJump, to: loopEnd, conditional: false)
            }

        case .breakStatement(let location):
            guard !loops.isEmpty else {
                report("'break' is only allowed inside a loop.", at: location)
                return
            }

            let loopIndex = loops.count - 1
            let targetDepth = loops[loopIndex].scopeDepthAtEntry
            emitScopeUnwind(to: targetDepth, at: location)
            let jump = emitPlaceholder(.jump(-1), at: location)
            loops[loopIndex].breakJumps.append(jump)

        case .continueStatement(let location):
            guard let loop = loops.last else {
                report("'continue' is only allowed inside a loop.", at: location)
                return
            }

            emitScopeUnwind(to: loop.scopeDepthAtEntry, at: location)
            emit(.jump(loop.conditionTarget), at: location)
        }
    }

    private mutating func compileScoped(_ statements: [Statement], at location: SourceLocation) {
        emit(.beginScope, at: location)
        scopeDepth += 1
        statements.forEach { compile(statement: $0) }
        scopeDepth -= 1
        emit(.endScope, at: location)
    }

    private mutating func emitScopeUnwind(to targetDepth: Int, at location: SourceLocation) {
        let count = max(0, scopeDepth - targetDepth)
        for _ in 0..<count {
            emit(.endScope, at: location)
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
