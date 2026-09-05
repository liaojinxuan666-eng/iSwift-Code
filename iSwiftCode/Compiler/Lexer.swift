import Foundation

enum TokenKind: Equatable, Sendable {
    case identifier(String)
    case integer(Int)
    case double(Double)
    case string(String)

    case letKeyword
    case varKeyword
    case ifKeyword
    case elseKeyword
    case whileKeyword
    case breakKeyword
    case continueKeyword
    case trueKeyword
    case falseKeyword
    case printKeyword

    case leftParen
    case rightParen
    case leftBrace
    case rightBrace
    case plus
    case minus
    case star
    case slash
    case bang
    case bangEqual
    case equal
    case equalEqual
    case less
    case lessEqual
    case greater
    case greaterEqual
    case andAnd
    case orOr
    case newline
    case semicolon
    case eof
}

struct Token: Equatable, Sendable {
    let kind: TokenKind
    let lexeme: String
    let location: SourceLocation
}

struct LexResult: Sendable {
    let tokens: [Token]
    let diagnostics: [CompilerDiagnostic]
}

struct Lexer {
    private let characters: [Character]
    private var current = 0
    private var line = 1
    private var column = 1
    private var tokens: [Token] = []
    private var diagnostics: [CompilerDiagnostic] = []

    init(source: String) {
        characters = Array(source)
    }

    mutating func scanTokens() -> LexResult {
        while !isAtEnd {
            scanToken()
        }
        tokens.append(Token(kind: .eof, lexeme: "", location: currentLocation))
        return LexResult(tokens: tokens, diagnostics: diagnostics)
    }

    private var isAtEnd: Bool { current >= characters.count }
    private var currentLocation: SourceLocation { SourceLocation(line: line, column: column) }

    private mutating func scanToken() {
        let location = currentLocation
        let character = advance()

        switch character {
        case " ", "\t", "\r":
            return
        case "\n":
            add(.newline, lexeme: "\n", location: location)
        case "(": add(.leftParen, lexeme: "(", location: location)
        case ")": add(.rightParen, lexeme: ")", location: location)
        case "{": add(.leftBrace, lexeme: "{", location: location)
        case "}": add(.rightBrace, lexeme: "}", location: location)
        case "+": add(.plus, lexeme: "+", location: location)
        case "-": add(.minus, lexeme: "-", location: location)
        case "*": add(.star, lexeme: "*", location: location)
        case ";": add(.semicolon, lexeme: ";", location: location)
        case "!": add(match("=") ? .bangEqual : .bang, lexeme: matchLexeme(from: location), location: location)
        case "=": add(match("=") ? .equalEqual : .equal, lexeme: matchLexeme(from: location), location: location)
        case "<": add(match("=") ? .lessEqual : .less, lexeme: matchLexeme(from: location), location: location)
        case ">": add(match("=") ? .greaterEqual : .greater, lexeme: matchLexeme(from: location), location: location)
        case "&":
            if match("&") {
                add(.andAnd, lexeme: "&&", location: location)
            } else {
                report("Expected '&' after '&'.", at: location)
            }
        case "|":
            if match("|") {
                add(.orOr, lexeme: "||", location: location)
            } else {
                report("Expected '|' after '|'.", at: location)
            }
        case "/":
            if match("/") {
                while peek() != "\n" && !isAtEnd { _ = advance() }
            } else {
                add(.slash, lexeme: "/", location: location)
            }
        case "\"":
            scanString(start: location)
        default:
            if character.isNumber {
                scanNumber(first: character, start: location)
            } else if isIdentifierStart(character) {
                scanIdentifier(first: character, start: location)
            } else {
                report("Unexpected character '\(character)'.", at: location)
            }
        }
    }

    private mutating func scanString(start: SourceLocation) {
        var value = ""

        while !isAtEnd {
            let character = advance()
            if character == "\"" {
                add(.string(value), lexeme: value, location: start)
                return
            }
            if character == "\n" {
                report("Unterminated string literal.", at: start)
                return
            }
            if character == "\\" && !isAtEnd {
                let escaped = advance()
                switch escaped {
                case "n": value.append("\n")
                case "t": value.append("\t")
                case "\"": value.append("\"")
                case "\\": value.append("\\")
                default:
                    report("Unsupported escape sequence '\\\(escaped)'.", at: currentLocation)
                    value.append(escaped)
                }
            } else {
                value.append(character)
            }
        }

        report("Unterminated string literal.", at: start)
    }

    private mutating func scanNumber(first: Character, start: SourceLocation) {
        var text = String(first)
        while peek().isNumber { text.append(advance()) }

        if peek() == "." && peekNext().isNumber {
            text.append(advance())
            while peek().isNumber { text.append(advance()) }
            if let value = Double(text) {
                add(.double(value), lexeme: text, location: start)
            }
        } else if let value = Int(text) {
            add(.integer(value), lexeme: text, location: start)
        }
    }

    private mutating func scanIdentifier(first: Character, start: SourceLocation) {
        var text = String(first)
        while isIdentifierPart(peek()) { text.append(advance()) }

        let kind: TokenKind
        switch text {
        case "let": kind = .letKeyword
        case "var": kind = .varKeyword
        case "if": kind = .ifKeyword
        case "else": kind = .elseKeyword
        case "while": kind = .whileKeyword
        case "break": kind = .breakKeyword
        case "continue": kind = .continueKeyword
        case "true": kind = .trueKeyword
        case "false": kind = .falseKeyword
        case "print": kind = .printKeyword
        default: kind = .identifier(text)
        }
        add(kind, lexeme: text, location: start)
    }

    private func isIdentifierStart(_ character: Character) -> Bool {
        character == "_" || character.isLetter
    }

    private func isIdentifierPart(_ character: Character) -> Bool {
        isIdentifierStart(character) || character.isNumber
    }

    @discardableResult
    private mutating func advance() -> Character {
        let character = characters[current]
        current += 1
        if character == "\n" {
            line += 1
            column = 1
        } else {
            column += 1
        }
        return character
    }

    private func peek() -> Character {
        isAtEnd ? "\0" : characters[current]
    }

    private func peekNext() -> Character {
        current + 1 >= characters.count ? "\0" : characters[current + 1]
    }

    private mutating func match(_ expected: Character) -> Bool {
        guard !isAtEnd, characters[current] == expected else { return false }
        _ = advance()
        return true
    }

    private func matchLexeme(from location: SourceLocation) -> String {
        let length = max(1, column - location.column)
        let start = max(0, current - length)
        return String(characters[start..<current])
    }

    private mutating func add(_ kind: TokenKind, lexeme: String, location: SourceLocation) {
        tokens.append(Token(kind: kind, lexeme: lexeme, location: location))
    }

    private mutating func report(_ message: String, at location: SourceLocation) {
        diagnostics.append(CompilerDiagnostic(severity: .error, message: message, location: location))
    }
}
