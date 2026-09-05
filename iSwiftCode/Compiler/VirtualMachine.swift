import Foundation

private struct VariableSlot {
    var value: RuntimeValue
    let mutable: Bool
}

private struct RuntimeFailure: Error {
    let message: String
    let location: SourceLocation
}

struct VirtualMachine {
    private let maximumInstructionCount = 100_000

    func execute(_ program: BytecodeProgram) -> RunResult {
        var stack: [RuntimeValue] = []
        var variables: [String: VariableSlot] = [:]
        var output: [String] = []
        var instructionPointer = 0
        var executed = 0

        do {
            while instructionPointer < program.instructions.count {
                guard executed < maximumInstructionCount else {
                    throw RuntimeFailure(message: "Execution limit exceeded.", location: .start)
                }

                let instruction = program.instructions[instructionPointer]
                instructionPointer += 1
                executed += 1

                switch instruction.operation {
                case .push(let value):
                    stack.append(value)
                case .load(let name):
                    guard let slot = variables[name] else {
                        throw RuntimeFailure(message: "Cannot find '\(name)' in scope.", location: instruction.location)
                    }
                    stack.append(slot.value)
                case .declare(let name, let mutable):
                    guard variables[name] == nil else {
                        throw RuntimeFailure(message: "Invalid redeclaration of '\(name)'.", location: instruction.location)
                    }
                    variables[name] = VariableSlot(value: try pop(&stack, at: instruction.location), mutable: mutable)
                case .assign(let name):
                    guard var slot = variables[name] else {
                        throw RuntimeFailure(message: "Cannot find '\(name)' in scope.", location: instruction.location)
                    }
                    guard slot.mutable else {
                        throw RuntimeFailure(message: "Cannot assign to value: '\(name)' is a 'let' constant.", location: instruction.location)
                    }
                    slot.value = try pop(&stack, at: instruction.location)
                    variables[name] = slot
                case .add:
                    let (lhs, rhs) = try operands(&stack, at: instruction.location)
                    stack.append(try add(lhs, rhs, at: instruction.location))
                case .subtract:
                    let (lhs, rhs) = try operands(&stack, at: instruction.location)
                    stack.append(try numeric(lhs, rhs, operation: -, at: instruction.location))
                case .multiply:
                    let (lhs, rhs) = try operands(&stack, at: instruction.location)
                    stack.append(try numeric(lhs, rhs, operation: *, at: instruction.location))
                case .divide:
                    let (lhs, rhs) = try operands(&stack, at: instruction.location)
                    stack.append(try divide(lhs, rhs, at: instruction.location))
                case .negate:
                    stack.append(try negate(try pop(&stack, at: instruction.location), at: instruction.location))
                case .not:
                    let value = try pop(&stack, at: instruction.location)
                    guard case .bool(let bool) = value else {
                        throw typeError("Unary '!' requires Bool, found \(value.typeName).", at: instruction.location)
                    }
                    stack.append(.bool(!bool))
                case .equal:
                    let (lhs, rhs) = try operands(&stack, at: instruction.location)
                    stack.append(.bool(lhs == rhs))
                case .notEqual:
                    let (lhs, rhs) = try operands(&stack, at: instruction.location)
                    stack.append(.bool(lhs != rhs))
                case .less, .lessEqual, .greater, .greaterEqual:
                    let (lhs, rhs) = try operands(&stack, at: instruction.location)
                    stack.append(try compare(lhs, rhs, using: instruction.operation, at: instruction.location))
                case .and, .or:
                    let (lhs, rhs) = try operands(&stack, at: instruction.location)
                    guard case .bool(let left) = lhs, case .bool(let right) = rhs else {
                        throw typeError("Logical operators require Bool operands.", at: instruction.location)
                    }
                    if case .and = instruction.operation {
                        stack.append(.bool(left && right))
                    } else {
                        stack.append(.bool(left || right))
                    }
                case .print:
                    output.append(try pop(&stack, at: instruction.location).displayText)
                case .pop:
                    _ = try pop(&stack, at: instruction.location)
                case .jumpIfFalse(let target):
                    let value = try pop(&stack, at: instruction.location)
                    guard case .bool(let condition) = value else {
                        throw typeError("If condition must be Bool, found \(value.typeName).", at: instruction.location)
                    }
                    if !condition { instructionPointer = target }
                case .jump(let target):
                    instructionPointer = target
                }
            }

            return RunResult(output: output.joined(separator: "\n"), diagnostics: [], instructionCount: executed)
        } catch let failure as RuntimeFailure {
            return RunResult(
                output: output.joined(separator: "\n"),
                diagnostics: [CompilerDiagnostic(severity: .error, message: failure.message, location: failure.location)],
                instructionCount: executed
            )
        } catch {
            return RunResult(
                output: output.joined(separator: "\n"),
                diagnostics: [CompilerDiagnostic(severity: .error, message: "Unknown runtime failure.", location: .start)],
                instructionCount: executed
            )
        }
    }

    private func pop(_ stack: inout [RuntimeValue], at location: SourceLocation) throws -> RuntimeValue {
        guard let value = stack.popLast() else {
            throw RuntimeFailure(message: "Internal stack underflow.", location: location)
        }
        return value
    }

    private func operands(_ stack: inout [RuntimeValue], at location: SourceLocation) throws -> (RuntimeValue, RuntimeValue) {
        let rhs = try pop(&stack, at: location)
        let lhs = try pop(&stack, at: location)
        return (lhs, rhs)
    }

    private func add(_ lhs: RuntimeValue, _ rhs: RuntimeValue, at location: SourceLocation) throws -> RuntimeValue {
        if case .string(let left) = lhs, case .string(let right) = rhs {
            return .string(left + right)
        }
        return try numeric(lhs, rhs, operation: +, at: location)
    }

    private func numeric(
        _ lhs: RuntimeValue,
        _ rhs: RuntimeValue,
        operation: (Double, Double) -> Double,
        at location: SourceLocation
    ) throws -> RuntimeValue {
        guard let left = number(lhs), let right = number(rhs) else {
            throw typeError("Numeric operator cannot be applied to \(lhs.typeName) and \(rhs.typeName).", at: location)
        }
        let result = operation(left, right)
        if case .int = lhs, case .int = rhs, result.rounded() == result {
            return .int(Int(result))
        }
        return .double(result)
    }

    private func divide(_ lhs: RuntimeValue, _ rhs: RuntimeValue, at location: SourceLocation) throws -> RuntimeValue {
        guard let left = number(lhs), let right = number(rhs) else {
            throw typeError("Operator '/' requires numeric operands.", at: location)
        }
        guard right != 0 else {
            throw RuntimeFailure(message: "Division by zero.", location: location)
        }
        if case .int = lhs, case .int = rhs {
            return .int(Int(left) / Int(right))
        }
        return .double(left / right)
    }

    private func negate(_ value: RuntimeValue, at location: SourceLocation) throws -> RuntimeValue {
        switch value {
        case .int(let number): return .int(-number)
        case .double(let number): return .double(-number)
        default: throw typeError("Unary '-' requires a number, found \(value.typeName).", at: location)
        }
    }

    private func compare(_ lhs: RuntimeValue, _ rhs: RuntimeValue, using operation: OpCode, at location: SourceLocation) throws -> RuntimeValue {
        guard let left = number(lhs), let right = number(rhs) else {
            throw typeError("Comparison requires numeric operands.", at: location)
        }
        switch operation {
        case .less: return .bool(left < right)
        case .lessEqual: return .bool(left <= right)
        case .greater: return .bool(left > right)
        case .greaterEqual: return .bool(left >= right)
        default: throw RuntimeFailure(message: "Internal comparison error.", location: location)
        }
    }

    private func number(_ value: RuntimeValue) -> Double? {
        switch value {
        case .int(let number): return Double(number)
        case .double(let number): return number
        default: return nil
        }
    }

    private func typeError(_ message: String, at location: SourceLocation) -> RuntimeFailure {
        RuntimeFailure(message: message, location: location)
    }
}
