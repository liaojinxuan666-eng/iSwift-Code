import Foundation

indirect enum Expression: Sendable {
    case literal(RuntimeValue, SourceLocation)
    case variable(String, SourceLocation)
    case unary(TokenKind, Expression, SourceLocation)
    case binary(Expression, TokenKind, Expression, SourceLocation)

    var location: SourceLocation {
        switch self {
        case .literal(_, let location), .variable(_, let location),
             .unary(_, _, let location), .binary(_, _, _, let location):
            return location
        }
    }
}

indirect enum Statement: Sendable {
    case declaration(name: String, mutable: Bool, initializer: Expression, location: SourceLocation)
    case assignment(name: String, value: Expression, location: SourceLocation)
    case print(Expression, SourceLocation)
    case expression(Expression, SourceLocation)
    case ifStatement(condition: Expression, thenBranch: [Statement], elseBranch: [Statement], location: SourceLocation)
}

struct ParseResult: Sendable {
    let statements: [Statement]
    let diagnostics: [CompilerDiagnostic]
}

private struct ParseFailure: Error {}

struct Parser {
    private let tokens: [Token]
    private var current = 0
    private var diagnostics: [CompilerDiagnostic] = []

    init(tokens: [Token]) {
        self.tokens = tokens
    }

    mutating func parse() -> ParseResult {
        var statements: [Statement] = []
        skipSeparators()

        while !isAtEnd {
            do {
                statements.append(try declaration())
            } catch {
                synchronize()
            }
            skipSeparators()
        }

        return ParseResult(statements: statements, diagnostics: diagnostics)
    }

    private mutating func declaration() throws -> Statement {
        if match(.letKeyword) { return try variableDeclaration(mutable: false, keyword: previous) }
        if match(.varKeyword) { return try variableDeclaration(mutable: true, keyword: previous) }
        return try statement()
    }

    private mutating func variableDeclaration(mutable: Bool, keyword: Token) throws -> Statement {
        let nameToken = try consumeIdentifier("Expected a variable name after '\(keyword.lexeme)'.")
        try consume(.equal, "Expected '=' after variable name.")
        let initializer = try expression()
        guard case .identifier(let name) = nameToken.kind else { throw ParseFailure() }
        return .declaration(name: name, mutable: mutable, initializer: initializer, location: keyword.location)
    }

    private mutating func statement() throws -> Statement {
        if match(.ifKeyword) { return try ifStatement(keyword: previous) }
        if match(.printKeyword) { return try printStatement(keyword: previous) }

        if case .identifier(let name) = peek.kind, checkNext(.equal) {
            let location = advance().location
            _ = advance()
            return .assignment(name: name, value: try expression(), location: location)
        }

        let value = try expression()
        return .expression(value, value.location)
    }

    private mutating func ifStatement(keyword: Token) throws -> Statement {
        let condition = try expression()
        try consume(.leftBrace, "Expected '{' after if condition.")
        let thenBranch = try block()
        var elseBranch: [Statement] = []

        skipSeparators()
        if match(.elseKeyword) {
            try consume(.leftBrace, "Expected '{' after else.")
            elseBranch = try block()
        }

        return .ifStatement(
            condition: condition,
            thenBranch: thenBranch,
            elseBranch: elseBranch,
            location: keyword.location
        )
    }

    private mutating func block() throws -> [Statement] {
        var statements: [Statement] = []
        skipSeparators()

        while !check(.rightBrace) && !isAtEnd {
            statements.append(try declaration())
            skipSeparators()
        }

        try consume(.rightBrace, "Expected '}' after block.")
        return statements
    }

    private mutating func printStatement(keyword: Token) throws -> Statement {
        try consume(.leftParen, "Expected '(' after print.")
        let value = try expression()
        try consume(.rightParen, "Expected ')' after print value.")
        return .print(value, keyword.location)
    }

    private mutating func expression() throws -> Expression { try logicalOr() }

    private mutating func logicalOr() throws -> Expression {
        var expression = try logicalAnd()
        while match(.orOr) {
            let operation = previous
            expression = .binary(expression, operation.kind, try logicalAnd(), operation.location)
        }
        return expression
    }

    private mutating func logicalAnd() throws -> Expression {
        var expression = try equality()
        while match(.andAnd) {
            let operation = previous
            expression = .binary(expression, operation.kind, try equality(), operation.location)
        }
        return expression
    }

    private mutating func equality() throws -> Expression {
        var expression = try comparison()
        while match(.equalEqual, .bangEqual) {
            let operation = previous
            expression = .binary(expression, operation.kind, try comparison(), operation.location)
        }
        return expression
    }

    private mutating func comparison() throws -> Expression {
        var expression = try term()
        while match(.less, .lessEqual, .greater, .greaterEqual) {
            let operation = previous
            expression = .binary(expression, operation.kind, try term(), operation.location)
        }
        return expression
    }

    private mutating func term() throws -> Expression {
        var expression = try factor()
        while match(.plus, .minus) {
            let operation = previous
            expression = .binary(expression, operation.kind, try factor(), operation.location)
        }
        return expression
    }

    private mutating func factor() throws -> Expression {
        var expression = try unary()
        while match(.star, .slash) {
            let operation = previous
            expression = .binary(expression, operation.kind, try unary(), operation.location)
        }
        return expression
    }

    private mutating func unary() throws -> Expression {
        if match(.bang, .minus) {
            let operation = previous
            return .unary(operation.kind, try unary(), operation.location)
        }
        return try primary()
    }

    private mutating func primary() throws -> Expression {
        if match(.trueKeyword) { return .literal(.bool(true), previous.location) }
        if match(.falseKeyword) { return .literal(.bool(false), previous.location) }

        switch peek.kind {
        case .integer(let value):
            let token = advance()
            return .literal(.int(value), token.location)
        case .double(let value):
            let token = advance()
            return .literal(.double(value), token.location)
        case .string(let value):
            let token = advance()
            return .literal(.string(value), token.location)
        case .identifier(let name):
            let token = advance()
            return .variable(name, token.location)
        default:
            break
        }

        if match(.leftParen) {
            let expression = try expression()
            try consume(.rightParen, "Expected ')' after expression.")
            return expression
        }

        report("Expected an expression.", at: peek.location)
        throw ParseFailure()
    }

    private var isAtEnd: Bool { check(.eof) }
    private var peek: Token { tokens[min(current, tokens.count - 1)] }
    private var previous: Token { tokens[max(0, current - 1)] }

    @discardableResult
    private mutating func advance() -> Token {
        if !isAtEnd { current += 1 }
        return previous
    }

    private func check(_ kind: TokenKind) -> Bool {
        sameCase(peek.kind, kind)
    }

    private func checkNext(_ kind: TokenKind) -> Bool {
        let index = current + 1
        guard index < tokens.count else { return false }
        return sameCase(tokens[index].kind, kind)
    }

    private mutating func match(_ kinds: TokenKind...) -> Bool {
        for kind in kinds where check(kind) {
            _ = advance()
            return true
        }
        return false
    }

    private mutating func consume(_ kind: TokenKind, _ message: String) throws {
        guard check(kind) else {
            report(message, at: peek.location)
            throw ParseFailure()
        }
        _ = advance()
    }

    private mutating func consumeIdentifier(_ message: String) throws -> Token {
        guard case .identifier = peek.kind else {
            report(message, at: peek.location)
            throw ParseFailure()
        }
        return advance()
    }

    private mutating func skipSeparators() {
        while match(.newline, .semicolon) {}
    }

    private mutating func synchronize() {
        while !isAtEnd {
            if check(.newline) || check(.semicolon) {
                skipSeparators()
                return
            }
            if check(.letKeyword) || check(.varKeyword) || check(.ifKeyword) || check(.printKeyword) || check(.rightBrace) {
                if check(.rightBrace) { _ = advance() }
                return
            }
            _ = advance()
        }
    }

    private mutating func report(_ message: String, at location: SourceLocation) {
        diagnostics.append(CompilerDiagnostic(severity: .error, message: message, location: location))
    }

    private func sameCase(_ lhs: TokenKind, _ rhs: TokenKind) -> Bool {
        switch (lhs, rhs) {
        case (.identifier, .identifier), (.integer, .integer), (.double, .double), (.string, .string),
             (.letKeyword, .letKeyword), (.varKeyword, .varKeyword), (.ifKeyword, .ifKeyword),
             (.elseKeyword, .elseKeyword), (.trueKeyword, .trueKeyword), (.falseKeyword, .falseKeyword),
             (.printKeyword, .printKeyword), (.leftParen, .leftParen), (.rightParen, .rightParen),
             (.leftBrace, .leftBrace), (.rightBrace, .rightBrace), (.plus, .plus), (.minus, .minus),
             (.star, .star), (.slash, .slash), (.bang, .bang), (.bangEqual, .bangEqual),
             (.equal, .equal), (.equalEqual, .equalEqual), (.less, .less), (.lessEqual, .lessEqual),
             (.greater, .greater), (.greaterEqual, .greaterEqual), (.andAnd, .andAnd), (.orOr, .orOr),
             (.newline, .newline), (.semicolon, .semicolon), (.eof, .eof):
            return true
        default:
            return false
        }
    }
}
