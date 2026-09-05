import Foundation

final class SwiftUIPreviewProvider: PreviewProvider {
    let manifest = PluginManifest(
        identifier: "com.iswift.preview.swiftui",
        displayName: "SwiftUI Preview Provider",
        version: "0.1.2",
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
    case malformedModifier(String)
    case malformedLayout(String)
    case unterminatedString
}

extension SwiftUIPreviewParseError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .noSupportedRoot:
            return "No supported SwiftUI preview root was found. Start with Text, VStack, HStack, ZStack, ScrollView, List, or NavigationStack."
        case .malformedNode(let name):
            return "Malformed SwiftUI preview node '\(name)'."
        case .malformedModifier(let name):
            return "Malformed SwiftUI preview modifier '.\(name)'."
        case .malformedLayout(let name):
            return "Malformed SwiftUI layout arguments for '\(name)'."
        case .unterminatedString:
            return "Unterminated string literal in preview source."
        }
    }
}

private enum SwiftUIPreviewToken: Equatable {
    case identifier(String)
    case string(String)
    case number(Double)
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
                if character.isNumber || character == "-" {
                    var end = source.index(after: index)
                    var hasDecimalPoint = false

                    while end < source.endIndex {
                        let next = source[end]

                        if next.isNumber {
                            end = source.index(after: end)
                            continue
                        }

                        if next == ".", !hasDecimalPoint {
                            hasDecimalPoint = true
                            end = source.index(after: end)
                            continue
                        }

                        break
                    }

                    let raw = String(source[index..<end])
                    if let number = Double(raw) {
                        tokens.append(.number(number))
                        index = source.index(before: end)
                    }
                } else if character.isLetter || character == "_" {
                    var end = source.index(after: index)

                    while end < source.endIndex {
                        let next = source[end]
                        guard next.isLetter || next.isNumber || next == "_" else {
                            break
                        }
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

    private struct ParsedContainer {
        let children: [PreviewNode]
        let layoutModifiers: [PreviewModifier]
    }

    private struct Parser {
        let tokens: [SwiftUIPreviewToken]
        var index = 0

        mutating func parseRoot() throws -> PreviewNode {
            while index < tokens.count {
                if case .identifier(let name) = tokens[index],
                   Self.isSupportedNode(name) {
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

            var base: PreviewNode

            switch name {
            case "Text":
                base = .text(try parseFirstStringArgument(nodeName: name))

            case "Image":
                base = .image(
                    systemName: try parseFirstStringArgument(nodeName: name)
                )

            case "Button":
                let title = try parseFirstStringArgument(nodeName: name)
                skipClosureIfPresent()
                base = .button(title: title)

            case "Spacer":
                skipParenthesizedArgumentsIfPresent()
                base = .spacer

            case "VStack":
                let container = try parseContainer(nodeName: name)
                base = .vStack(children: container.children)
                for modifier in container.layoutModifiers {
                    base = base.applying(modifier)
                }

            case "HStack":
                let container = try parseContainer(nodeName: name)
                base = .hStack(children: container.children)
                for modifier in container.layoutModifiers {
                    base = base.applying(modifier)
                }

            case "ZStack":
                let container = try parseContainer(nodeName: name)
                base = .zStack(children: container.children)
                for modifier in container.layoutModifiers {
                    base = base.applying(modifier)
                }

            case "ScrollView":
                let container = try parseContainer(nodeName: name)
                base = .scrollView(children: container.children)

            case "List":
                let container = try parseContainer(nodeName: name)
                base = .list(children: container.children)

            case "NavigationStack":
                let container = try parseContainer(nodeName: name)
                base = .navigationStack(children: container.children)

            default:
                throw SwiftUIPreviewParseError.noSupportedRoot
            }

            return try parseModifiers(on: base)
        }

        mutating func parseModifiers(on base: PreviewNode) throws -> PreviewNode {
            var node = base

            while index + 1 < tokens.count,
                  tokens[index] == .dot,
                  case .identifier(let name) = tokens[index + 1] {
                guard Self.isSupportedModifier(name) else {
                    break
                }

                index += 2
                node = node.applying(try parseModifier(named: name))
            }

            return node
        }

        mutating func parseModifier(named name: String) throws -> PreviewModifier {
            guard consume(.leftParen) else {
                throw SwiftUIPreviewParseError.malformedModifier(name)
            }

            let arguments = collectArgumentsUntilRightParen()

            guard consume(.rightParen) else {
                throw SwiftUIPreviewParseError.malformedModifier(name)
            }

            switch name {
            case "padding":
                if arguments.isEmpty {
                    return .padding(nil)
                }

                if let value = firstNumber(in: arguments) {
                    return .padding(value)
                }

                throw SwiftUIPreviewParseError.malformedModifier(name)

            case "cornerRadius":
                guard let value = firstNumber(in: arguments) else {
                    throw SwiftUIPreviewParseError.malformedModifier(name)
                }
                return .cornerRadius(value)

            case "foregroundStyle":
                guard let color = parseColor(from: arguments) else {
                    throw SwiftUIPreviewParseError.malformedModifier(name)
                }
                return .foregroundStyle(color)

            case "background":
                guard let color = parseColor(from: arguments) else {
                    throw SwiftUIPreviewParseError.malformedModifier(name)
                }
                return .background(color)

            case "font":
                guard let font = parseFont(from: arguments) else {
                    throw SwiftUIPreviewParseError.malformedModifier(name)
                }
                return .font(font)

            case "frame":
                return .frame(try parseFrame(arguments))

            default:
                throw SwiftUIPreviewParseError.malformedModifier(name)
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

                if tokens[index] == .rightParen {
                    break
                }

                index += 1
            }

            throw SwiftUIPreviewParseError.malformedNode(nodeName)
        }

        mutating func parseContainer(nodeName: String) throws -> ParsedContainer {
            var arguments: [SwiftUIPreviewToken] = []

            if consume(.leftParen) {
                arguments = collectArgumentsUntilRightParen()

                guard consume(.rightParen) else {
                    throw SwiftUIPreviewParseError.malformedLayout(nodeName)
                }
            }

            let layoutModifiers = try parseContainerLayout(
                nodeName: nodeName,
                arguments: arguments
            )

            guard consume(.leftBrace) else {
                throw SwiftUIPreviewParseError.malformedNode(nodeName)
            }

            var children: [PreviewNode] = []
            var nestedUnknownBraceDepth = 0

            while index < tokens.count {
                if tokens[index] == .rightBrace,
                   nestedUnknownBraceDepth == 0 {
                    index += 1
                    return ParsedContainer(
                        children: children,
                        layoutModifiers: layoutModifiers
                    )
                }

                if case .identifier(let name) = tokens[index],
                   Self.isSupportedNode(name) {
                    children.append(try parseNode())
                    continue
                }

                if tokens[index] == .leftBrace {
                    nestedUnknownBraceDepth += 1
                } else if tokens[index] == .rightBrace,
                          nestedUnknownBraceDepth > 0 {
                    nestedUnknownBraceDepth -= 1
                }

                index += 1
            }

            throw SwiftUIPreviewParseError.malformedNode(nodeName)
        }

        func parseContainerLayout(
            nodeName: String,
            arguments: [SwiftUIPreviewToken]
        ) throws -> [PreviewModifier] {
            guard nodeName == "VStack" ||
                    nodeName == "HStack" ||
                    nodeName == "ZStack" else {
                return []
            }

            var modifiers: [PreviewModifier] = []
            var argumentIndex = 0

            while argumentIndex < arguments.count {
                guard case .identifier(let label) = arguments[argumentIndex],
                      argumentIndex + 1 < arguments.count,
                      arguments[argumentIndex + 1] == .colon else {
                    argumentIndex += 1
                    continue
                }

                argumentIndex += 2
                guard argumentIndex < arguments.count else {
                    throw SwiftUIPreviewParseError.malformedLayout(nodeName)
                }

                switch label {
                case "spacing":
                    guard case .number(let value) = arguments[argumentIndex] else {
                        throw SwiftUIPreviewParseError.malformedLayout(nodeName)
                    }
                    modifiers.append(.stackSpacing(value))

                case "alignment":
                    guard let alignmentName = dotIdentifier(
                        arguments,
                        at: &argumentIndex
                    ) else {
                        throw SwiftUIPreviewParseError.malformedLayout(nodeName)
                    }

                    switch nodeName {
                    case "VStack":
                        guard let alignment = PreviewHorizontalAlignment(
                            rawValue: alignmentName
                        ) else {
                            throw SwiftUIPreviewParseError.malformedLayout(nodeName)
                        }
                        modifiers.append(.horizontalAlignment(alignment))

                    case "HStack":
                        guard let alignment = PreviewVerticalAlignment(
                            rawValue: alignmentName
                        ) else {
                            throw SwiftUIPreviewParseError.malformedLayout(nodeName)
                        }
                        modifiers.append(.verticalAlignment(alignment))

                    case "ZStack":
                        guard let alignment = PreviewAlignment(
                            rawValue: alignmentName
                        ) else {
                            throw SwiftUIPreviewParseError.malformedLayout(nodeName)
                        }
                        modifiers.append(.zStackAlignment(alignment))

                    default:
                        break
                    }

                default:
                    break
                }

                argumentIndex += 1
            }

            return modifiers
        }

        func dotIdentifier(
            _ arguments: [SwiftUIPreviewToken],
            at index: inout Int
        ) -> String? {
            guard index < arguments.count else {
                return nil
            }

            if arguments[index] == .dot,
               index + 1 < arguments.count,
               case .identifier(let value) = arguments[index + 1] {
                index += 1
                return value
            }

            if case .identifier(let value) = arguments[index] {
                return value
            }

            return nil
        }

        mutating func collectArgumentsUntilRightParen() -> [SwiftUIPreviewToken] {
            var result: [SwiftUIPreviewToken] = []
            var nestedDepth = 0

            while index < tokens.count {
                if tokens[index] == .leftParen {
                    nestedDepth += 1
                } else if tokens[index] == .rightParen {
                    if nestedDepth == 0 {
                        break
                    }
                    nestedDepth -= 1
                }

                result.append(tokens[index])
                index += 1
            }

            return result
        }

        func firstNumber(in arguments: [SwiftUIPreviewToken]) -> Double? {
            for token in arguments {
                if case .number(let value) = token {
                    return value
                }
            }
            return nil
        }

        func parseColor(from arguments: [SwiftUIPreviewToken]) -> PreviewColor? {
            for token in arguments.reversed() {
                if case .identifier(let value) = token,
                   let color = PreviewColor(rawValue: value) {
                    return color
                }
            }
            return nil
        }

        func parseFont(from arguments: [SwiftUIPreviewToken]) -> PreviewFont? {
            for token in arguments.reversed() {
                if case .identifier(let value) = token,
                   let font = PreviewFont(rawValue: value) {
                    return font
                }
            }
            return nil
        }

        func parseFrame(_ arguments: [SwiftUIPreviewToken]) throws -> PreviewFrame {
            var width: Double?
            var height: Double?
            var maxWidth: PreviewDimension?
            var maxHeight: PreviewDimension?
            var argumentIndex = 0

            while argumentIndex < arguments.count {
                guard case .identifier(let label) = arguments[argumentIndex],
                      argumentIndex + 1 < arguments.count,
                      arguments[argumentIndex + 1] == .colon else {
                    argumentIndex += 1
                    continue
                }

                argumentIndex += 2
                guard argumentIndex < arguments.count else {
                    break
                }

                switch label {
                case "width":
                    if case .number(let value) = arguments[argumentIndex] {
                        width = value
                    }

                case "height":
                    if case .number(let value) = arguments[argumentIndex] {
                        height = value
                    }

                case "maxWidth":
                    maxWidth = parseDimension(
                        arguments,
                        at: &argumentIndex
                    )

                case "maxHeight":
                    maxHeight = parseDimension(
                        arguments,
                        at: &argumentIndex
                    )

                default:
                    break
                }

                argumentIndex += 1
            }

            guard width != nil ||
                    height != nil ||
                    maxWidth != nil ||
                    maxHeight != nil else {
                throw SwiftUIPreviewParseError.malformedModifier("frame")
            }

            return PreviewFrame(
                width: width,
                height: height,
                maxWidth: maxWidth,
                maxHeight: maxHeight
            )
        }

        func parseDimension(
            _ arguments: [SwiftUIPreviewToken],
            at index: inout Int
        ) -> PreviewDimension? {
            guard index < arguments.count else {
                return nil
            }

            if case .number(let value) = arguments[index] {
                return .points(value)
            }

            if arguments[index] == .dot,
               index + 1 < arguments.count,
               case .identifier(let name) = arguments[index + 1],
               name == "infinity" {
                index += 1
                return .infinity
            }

            if case .identifier(let name) = arguments[index],
               name == "infinity" {
                return .infinity
            }

            return nil
        }

        mutating func skipParenthesizedArgumentsIfPresent() {
            guard index < tokens.count,
                  tokens[index] == .leftParen else {
                return
            }

            var depth = 0

            while index < tokens.count {
                if tokens[index] == .leftParen {
                    depth += 1
                }

                if tokens[index] == .rightParen {
                    depth -= 1
                    index += 1

                    if depth == 0 {
                        return
                    }

                    continue
                }

                index += 1
            }
        }

        mutating func skipClosureIfPresent() {
            guard index < tokens.count,
                  tokens[index] == .leftBrace else {
                return
            }

            var depth = 0

            while index < tokens.count {
                if tokens[index] == .leftBrace {
                    depth += 1
                }

                if tokens[index] == .rightBrace {
                    depth -= 1
                    index += 1

                    if depth == 0 {
                        return
                    }

                    continue
                }

                index += 1
            }
        }

        mutating func consume(_ token: SwiftUIPreviewToken) -> Bool {
            guard index < tokens.count,
                  tokens[index] == token else {
                return false
            }

            index += 1
            return true
        }

        static func isSupportedNode(_ name: String) -> Bool {
            switch name {
            case "Text",
                 "Button",
                 "Image",
                 "Spacer",
                 "VStack",
                 "HStack",
                 "ZStack",
                 "ScrollView",
                 "List",
                 "NavigationStack":
                return true

            default:
                return false
            }
        }

        static func isSupportedModifier(_ name: String) -> Bool {
            switch name {
            case "padding",
                 "frame",
                 "foregroundStyle",
                 "background",
                 "font",
                 "cornerRadius":
                return true

            default:
                return false
            }
        }
    }
}
