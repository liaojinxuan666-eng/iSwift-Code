import Foundation

final class SwiftUIPreviewProvider: PreviewProvider {
    let manifest = PluginManifest(
        identifier: "com.iswift.preview.swiftui",
        displayName: "SwiftUI Preview Provider",
        version: "0.1.0",
        capabilities: [.preview],
        executionMode: .builtIn
    )

    let providerName = "SwiftUI Preview"
    let supportedPlatforms: Set<PreviewPlatform> = [.iOS]

    func makePreview(_ request: PreviewRequest) throws -> PreviewProviderResult {
        guard supportedPlatforms.contains(request.platform) else {
            throw PreviewProviderError.unsupportedPlatform(request.platform)
        }

        guard !request.files.isEmpty else {
            throw PreviewProviderError.invalidRequest("Preview request contains no source files.")
        }

        let selectedFile: PreviewSourceFile
        if let entry = request.entryFilePath,
           let match = request.files.first(where: { $0.path == entry }) {
            selectedFile = match
        } else if let swiftFile = request.files.first(where: { $0.path.lowercased().hasSuffix(".swift") }) {
            selectedFile = swiftFile
        } else {
            throw PreviewProviderError.invalidRequest("SwiftUI Preview requires at least one Swift source file.")
        }

        do {
            let root = try SwiftUIPreviewSourceParser(source: selectedFile.contents).parse()
            return PreviewProviderResult(
                document: PreviewDocument(
                    root: root,
                    sourceFilePath: selectedFile.path,
                    title: selectedFile.path
                )
            )
        } catch let error as SwiftUIPreviewParseError {
            return PreviewProviderResult(
                diagnostics: [
                    PreviewDiagnostic(
                        severity: .error,
                        message: error.localizedDescription,
                        filePath: selectedFile.path
                    )
                ]
            )
        }
    }
}

enum SwiftUIPreviewParseError: Error, Equatable, Sendable {
    case noSupportedRoot
    case malformedNode(String)
    case unterminatedString
}

extension SwiftUIPreviewParseError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .noSupportedRoot:
            return "No supported SwiftUI preview root was found. Start with Text, VStack, HStack, ZStack, ScrollView, List, or NavigationStack."
        case .malformedNode(let name):
            return "Malformed SwiftUI preview node '\(name)'."
        case .unterminatedString:
            return "Unterminated string literal in preview source."
        }
    }
}

private enum SwiftUIPreviewToken: Equatable {
    case identifier(String)
    case string(String)
    case leftParen
    case rightParen
    case leftBrace
    case rightBrace
    case colon
    case comma
    case dot
}

private struct SwiftUIPreviewLexer {
    let source: String

    func lex() throws -> [SwiftUIPreviewToken] {
        var tokens: [SwiftUIPreviewToken] = []
        var index = source.startIndex

        while index < source.endIndex {
            let character = source[index]

            if character.isWhitespace {
                index = source.index(after: index)
                continue
            }

            if character == "/" {
                let next = source.index(after: index)
                if next < source.endIndex, source[next] == "/" {
                    index = source.index(after: next)
                    while index < source.endIndex, source[index] != "\n" {
                        index = source.index(after: index)
                    }
                    continue
                }
            }

            switch character {
            case "(": tokens.append(.leftParen)
            case ")": tokens.append(.rightParen)
            case "{": tokens.append(.leftBrace)
            case "}": tokens.append(.rightBrace)
            case ":": tokens.append(.colon)
            case ",": tokens.append(.comma)
            case ".": tokens.append(.dot)
            case "\"":
                var value = ""
                index = source.index(after: index)
                var terminated = false

                while index < source.endIndex {
                    let current = source[index]
                    if current == "\"" {
                        terminated = true
                        break
                    }
                    if current == "\\" {
                        let escaped = source.index(after: index)
                        if escaped < source.endIndex {
                            let escapedCharacter = source[escaped]
                            switch escapedCharacter {
                            case "n": value.append("\n")
                            case "t": value.append("\t")
                            case "\"": value.append("\"")
                            case "\\": value.append("\\")
                            default: value.append(escapedCharacter)
                            }
                            index = escaped
                        }
                    } else {
                        value.append(current)
                    }
                    index = source.index(after: index)
                }

                guard terminated else {
                    throw SwiftUIPreviewParseError.unterminatedString
                }
                tokens.append(.string(value))
            default:
                if character.isLetter || character == "_" {
                    var end = source.index(after: index)
                    while end < source.endIndex {
                        let next = source[end]
                        guard next.isLetter || next.isNumber || next == "_" else { break }
                        end = source.index(after: end)
                    }
                    tokens.append(.identifier(String(source[index..<end])))
                    index = source.index(before: end)
                }
            }

            index = source.index(after: index)
        }

        return tokens
    }
}

private struct SwiftUIPreviewSourceParser {
    let source: String

    func parse() throws -> PreviewNode {
        let tokens = try SwiftUIPreviewLexer(source: source).lex()
        var parser = Parser(tokens: tokens)
        return try parser.parseRoot()
    }

    private struct Parser {
        let tokens: [SwiftUIPreviewToken]
        var index = 0

        mutating func parseRoot() throws -> PreviewNode {
            while index < tokens.count {
                if case .identifier(let name) = tokens[index], Self.isSupported(name) {
                    return try parseNode()
                }
                index += 1
            }
            throw SwiftUIPreviewParseError.noSupportedRoot
        }

        mutating func parseNode() throws -> PreviewNode {
            guard index < tokens.count,
                  case .identifier(let name) = tokens[index] else {
                throw SwiftUIPreviewParseError.noSupportedRoot
            }
            index += 1

            switch name {
            case "Text":
                return .text(try parseFirstStringArgument(nodeName: name))
            case "Image":
                return .image(systemName: try parseFirstStringArgument(nodeName: name))
            case "Button":
                let title = try parseFirstStringArgument(nodeName: name)
                skipClosureIfPresent()
                return .button(title: title)
            case "Spacer":
                skipParenthesizedArgumentsIfPresent()
                return .spacer
            case "VStack":
                return .vStack(children: try parseContainerChildren(nodeName: name))
            case "HStack":
                return .hStack(children: try parseContainerChildren(nodeName: name))
            case "ZStack":
                return .zStack(children: try parseContainerChildren(nodeName: name))
            case "ScrollView":
                return .scrollView(children: try parseContainerChildren(nodeName: name))
            case "List":
                return .list(children: try parseContainerChildren(nodeName: name))
            case "NavigationStack":
                return .navigationStack(children: try parseContainerChildren(nodeName: name))
            default:
                throw SwiftUIPreviewParseError.noSupportedRoot
            }
        }

        mutating func parseFirstStringArgument(nodeName: String) throws -> String {
            guard consume(.leftParen) else {
                throw SwiftUIPreviewParseError.malformedNode(nodeName)
            }

            while index < tokens.count {
                if case .string(let value) = tokens[index] {
                    index += 1
                    while index < tokens.count, tokens[index] != .rightParen {
                        index += 1
                    }
                    _ = consume(.rightParen)
                    return value
                }
                if tokens[index] == .rightParen { break }
                index += 1
            }

            throw SwiftUIPreviewParseError.malformedNode(nodeName)
        }

        mutating func parseContainerChildren(nodeName: String) throws -> [PreviewNode] {
            skipParenthesizedArgumentsIfPresent()
            guard consume(.leftBrace) else {
                throw SwiftUIPreviewParseError.malformedNode(nodeName)
            }

            var children: [PreviewNode] = []
            var nestedUnknownBraceDepth = 0

            while index < tokens.count {
                if tokens[index] == .rightBrace, nestedUnknownBraceDepth == 0 {
                    index += 1
                    return children
                }

                if case .identifier(let name) = tokens[index], Self.isSupported(name) {
                    children.append(try parseNode())
                    continue
                }

                if tokens[index] == .leftBrace {
                    nestedUnknownBraceDepth += 1
                } else if tokens[index] == .rightBrace, nestedUnknownBraceDepth > 0 {
                    nestedUnknownBraceDepth -= 1
                }
                index += 1
            }

            throw SwiftUIPreviewParseError.malformedNode(nodeName)
        }

        mutating func skipParenthesizedArgumentsIfPresent() {
            guard index < tokens.count, tokens[index] == .leftParen else { return }
            var depth = 0
            while index < tokens.count {
                if tokens[index] == .leftParen { depth += 1 }
                if tokens[index] == .rightParen {
                    depth -= 1
                    index += 1
                    if depth == 0 { return }
                    continue
                }
                index += 1
            }
        }

        mutating func skipClosureIfPresent() {
            guard index < tokens.count, tokens[index] == .leftBrace else { return }
            var depth = 0
            while index < tokens.count {
                if tokens[index] == .leftBrace { depth += 1 }
                if tokens[index] == .rightBrace {
                    depth -= 1
                    index += 1
                    if depth == 0 { return }
                    continue
                }
                index += 1
            }
        }

        mutating func consume(_ token: SwiftUIPreviewToken) -> Bool {
            guard index < tokens.count, tokens[index] == token else { return false }
            index += 1
            return true
        }

        static func isSupported(_ name: String) -> Bool {
            switch name {
            case "Text", "Button", "Image", "Spacer", "VStack", "HStack", "ZStack", "ScrollView", "List", "NavigationStack":
                return true
            default:
                return false
            }
        }
    }
}
