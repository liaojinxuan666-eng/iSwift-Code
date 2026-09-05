import Foundation

/// Adds safe Button action lowering on top of the existing interactive SwiftUI
/// preview provider.
///
/// Arbitrary source closures are never executed. Only a deliberately small
/// mutation grammar is translated to PreviewActionProgram and validated against
/// the preview document's @State definitions before it reaches the runtime.
final class SwiftUIButtonActionPreviewProvider: PreviewProvider {
    private let base = SwiftUIInteractivePreviewProvider()

    var manifest: PluginManifest {
        base.manifest
    }

    var providerName: String {
        base.providerName
    }

    var supportedPlatforms: Set<PreviewPlatform> {
        base.supportedPlatforms
    }

    func activate(context: PluginHostContext) throws {
        try base.activate(context: context)
    }

    func deactivate() {
        base.deactivate()
    }

    func makePreview(
        _ request: PreviewRequest
    ) throws -> PreviewProviderResult {
        guard let selectedIndex = selectedFileIndex(
            in: request
        ) else {
            return try base.makePreview(request)
        }

        let selectedFile = request.files[selectedIndex]
        let rewrite: PreviewButtonActionRewrite

        do {
            rewrite = try PreviewButtonActionSourceRewriter(
                source: selectedFile.contents
            ).rewrite()
        } catch {
            return diagnosticResult(
                error,
                filePath: selectedFile.path
            )
        }

        guard !rewrite.buttons.isEmpty else {
            return try base.makePreview(request)
        }

        var rewrittenFiles = request.files
        rewrittenFiles[selectedIndex] = PreviewSourceFile(
            path: selectedFile.path,
            contents: rewrite.source
        )

        let result = try base.makePreview(
            PreviewRequest(
                files: rewrittenFiles,
                entryFilePath: request.entryFilePath,
                platform: request.platform,
                deviceFamily: request.deviceFamily
            )
        )

        guard let document = result.document,
              result.succeeded else {
            return result
        }

        do {
            let buttons = try validatedButtons(
                rewrite.buttons,
                definitions: document.stateDefinitions
            )

            return PreviewProviderResult(
                document: PreviewDocument(
                    root: replacingActionMarkers(
                        in: document.root,
                        buttons: buttons
                    ),
                    stateDefinitions: document.stateDefinitions,
                    sourceFilePath: document.sourceFilePath,
                    title: document.title
                ),
                diagnostics: result.diagnostics
            )
        } catch {
            return diagnosticResult(
                error,
                filePath: selectedFile.path
            )
        }
    }

    private func selectedFileIndex(
        in request: PreviewRequest
    ) -> Int? {
        if let entry = request.entryFilePath,
           let index = request.files.firstIndex(
               where: { $0.path == entry }
           ) {
            return index
        }

        return request.files.firstIndex {
            $0.path.lowercased().hasSuffix(".swift")
        }
    }

    private func validatedButtons(
        _ buttons: [PreviewActionButtonSpec],
        definitions: [PreviewStateDefinition]
    ) throws -> [String: PreviewActionButtonSpec] {
        var result: [String: PreviewActionButtonSpec] = [:]

        for button in buttons {
            try PreviewActionValidator.validate(
                button.program,
                definitions: definitions
            )
            result[button.marker] = button
        }

        return result
    }

    private func replacingActionMarkers(
        in node: PreviewNode,
        buttons: [String: PreviewActionButtonSpec]
    ) -> PreviewNode {
        switch node {
        case .text(let marker):
            guard let button = buttons[marker] else {
                return node
            }

            return .actionButton(
                title: button.title,
                program: button.program
            )

        case .vStack(let children):
            return .vStack(
                children: children.map {
                    replacingActionMarkers(
                        in: $0,
                        buttons: buttons
                    )
                }
            )

        case .hStack(let children):
            return .hStack(
                children: children.map {
                    replacingActionMarkers(
                        in: $0,
                        buttons: buttons
                    )
                }
            )

        case .zStack(let children):
            return .zStack(
                children: children.map {
                    replacingActionMarkers(
                        in: $0,
                        buttons: buttons
                    )
                }
            )

        case .scrollView(let children):
            return .scrollView(
                children: children.map {
                    replacingActionMarkers(
                        in: $0,
                        buttons: buttons
                    )
                }
            )

        case .list(let children):
            return .list(
                children: children.map {
                    replacingActionMarkers(
                        in: $0,
                        buttons: buttons
                    )
                }
            )

        case .navigationStack(let children):
            return .navigationStack(
                children: children.map {
                    replacingActionMarkers(
                        in: $0,
                        buttons: buttons
                    )
                }
            )

        case .modified(let base, let modifiers):
            return .modified(
                base: replacingActionMarkers(
                    in: base,
                    buttons: buttons
                ),
                modifiers: modifiers
            )

        default:
            return node
        }
    }

    private func diagnosticResult(
        _ error: Error,
        filePath: String
    ) -> PreviewProviderResult {
        PreviewProviderResult(
            diagnostics: [
                PreviewDiagnostic(
                    severity: .error,
                    message: error.localizedDescription,
                    filePath: filePath
                )
            ]
        )
    }
}

private struct PreviewActionButtonSpec {
    let marker: String
    let title: String
    let program: PreviewActionProgram
}

private struct PreviewButtonActionRewrite {
    let source: String
    let buttons: [PreviewActionButtonSpec]
}

private enum PreviewButtonActionError: Error {
    case malformedHeader
    case malformedClosure(String)
    case unsupportedStatement(
        button: String,
        statement: String
    )
}

extension PreviewButtonActionError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .malformedHeader:
            return "Malformed Button preview. Use Button(\"Title\") { ... }."

        case .malformedClosure(let title):
            return "Button '\(title)' has a malformed preview action closure."

        case .unsupportedStatement(
            let button,
            let statement
        ):
            return "Button '\(button)' contains an unsupported App Preview action: \(statement)"
        }
    }
}

private struct PreviewButtonActionSourceRewriter {
    let source: String

    func rewrite() throws -> PreviewButtonActionRewrite {
        var output = ""
        var buttons: [PreviewActionButtonSpec] = []
        var cursor = source.startIndex

        while let start = nextButtonStart(from: cursor) {
            output += String(source[cursor..<start])

            let parsed = try parseButton(
                startingAt: start,
                number: buttons.count
            )

            let statements = splitStatements(parsed.body)

            // Empty Button closures remain normal legacy preview Buttons.
            guard !statements.isEmpty else {
                output += String(source[start..<parsed.end])
                cursor = parsed.end
                continue
            }

            let program = try parseProgram(
                statements,
                buttonTitle: parsed.title
            )

            let marker = "__ISWIFT_ACTION_BUTTON_\(buttons.count)__"
            output += "Text(\"\(marker)\")"
            buttons.append(
                PreviewActionButtonSpec(
                    marker: marker,
                    title: parsed.title,
                    program: program
                )
            )
            cursor = parsed.end
        }

        output += String(source[cursor...])

        return PreviewButtonActionRewrite(
            source: output,
            buttons: buttons
        )
    }

    private func nextButtonStart(
        from start: String.Index
    ) -> String.Index? {
        var index = start

        while index < source.endIndex {
            let character = source[index]

            if character == "\"" {
                index = skipString(from: index)
                continue
            }

            if character == "/",
               let next = nextIndex(after: index),
               source[next] == "/" {
                index = skipLineComment(from: next)
                continue
            }

            if isIdentifierStart(character) {
                let wordStart = index
                index = identifierEnd(from: index)
                let word = String(source[wordStart..<index])

                if word == "Button" {
                    var lookahead = index
                    skipWhitespace(at: &lookahead)

                    if lookahead < source.endIndex,
                       source[lookahead] == "(" {
                        return wordStart
                    }
                }

                continue
            }

            index = source.index(after: index)
        }

        return nil
    }

    private func parseButton(
        startingAt start: String.Index,
        number: Int
    ) throws -> (
        title: String,
        body: String,
        end: String.Index
    ) {
        var cursor = identifierEnd(from: start)
        skipWhitespace(at: &cursor)

        guard cursor < source.endIndex,
              source[cursor] == "(" else {
            throw PreviewButtonActionError.malformedHeader
        }

        let openParen = cursor
        let closeParen = try matchingDelimiter(
            from: openParen,
            open: "(",
            close: ")"
        )

        let headerStart = source.index(after: openParen)
        let header = String(source[headerStart..<closeParen])
        let title = try parseTitle(header)

        cursor = source.index(after: closeParen)
        skipWhitespace(at: &cursor)

        guard cursor < source.endIndex,
              source[cursor] == "{" else {
            throw PreviewButtonActionError.malformedClosure(title)
        }

        let openBrace = cursor
        let closeBrace = try matchingDelimiter(
            from: openBrace,
            open: "{",
            close: "}"
        )

        let bodyStart = source.index(after: openBrace)
        let body = String(source[bodyStart..<closeBrace])

        return (
            title,
            body,
            source.index(after: closeBrace)
        )
    }

    private func parseTitle(
        _ header: String
    ) throws -> String {
        let pattern = #"^\s*"((?:\\.|[^"])*)"\s*$"#

        guard let match = firstMatch(
            pattern: pattern,
            in: header
        ),
        let range = Range(
            match.range(at: 1),
            in: header
        ) else {
            throw PreviewButtonActionError.malformedHeader
        }

        return unescapeString(String(header[range]))
    }

    private func parseProgram(
        _ statements: [String],
        buttonTitle: String
    ) throws -> PreviewActionProgram {
        var actions: [PreviewAction] = []

        for statement in statements {
            if let parsed = parseAdd(statement) {
                actions.append(
                    .add(
                        stateName: parsed.name,
                        amount: parsed.amount
                    )
                )
                continue
            }

            if let parsed = parseSubtract(statement) {
                actions.append(
                    .add(
                        stateName: parsed.name,
                        amount: -parsed.amount
                    )
                )
                continue
            }

            if let stateName = parseToggle(statement) {
                actions.append(
                    .toggle(stateName: stateName)
                )
                continue
            }

            if let parsed = parseSet(statement) {
                actions.append(
                    .set(
                        stateName: parsed.name,
                        value: parsed.value
                    )
                )
                continue
            }

            throw PreviewButtonActionError.unsupportedStatement(
                button: buttonTitle,
                statement: statement
            )
        }

        return PreviewActionProgram(actions: actions)
    }

    private func parseAdd(
        _ statement: String
    ) -> (name: String, amount: Double)? {
        parseNumericMutation(
            statement,
            operatorPattern: #"\+="#
        )
    }

    private func parseSubtract(
        _ statement: String
    ) -> (name: String, amount: Double)? {
        parseNumericMutation(
            statement,
            operatorPattern: #"-="#
        )
    }

    private func parseNumericMutation(
        _ statement: String,
        operatorPattern: String
    ) -> (name: String, amount: Double)? {
        let pattern =
            #"^\s*([A-Za-z_][A-Za-z0-9_]*)\s*"# +
            operatorPattern +
            #"\s*(-?(?:\d+(?:\.\d*)?|\.\d+))\s*$"#

        guard let match = firstMatch(
            pattern: pattern,
            in: statement
        ),
        let nameRange = Range(
            match.range(at: 1),
            in: statement
        ),
        let amountRange = Range(
            match.range(at: 2),
            in: statement
        ),
        let amount = Double(statement[amountRange]) else {
            return nil
        }

        return (
            String(statement[nameRange]),
            amount
        )
    }

    private func parseToggle(
        _ statement: String
    ) -> String? {
        let pattern =
            #"^\s*([A-Za-z_][A-Za-z0-9_]*)\s*\.\s*toggle\s*\(\s*\)\s*$"#

        guard let match = firstMatch(
            pattern: pattern,
            in: statement
        ),
        let range = Range(
            match.range(at: 1),
            in: statement
        ) else {
            return nil
        }

        return String(statement[range])
    }

    private func parseSet(
        _ statement: String
    ) -> (name: String, value: PreviewStateValue)? {
        let pattern =
            #"^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*("(?:\\.|[^"])*"|true|false|-?(?:\d+(?:\.\d*)?|\.\d+))\s*$"#

        guard let match = firstMatch(
            pattern: pattern,
            in: statement
        ),
        let nameRange = Range(
            match.range(at: 1),
            in: statement
        ),
        let valueRange = Range(
            match.range(at: 2),
            in: statement
        ),
        let value = parseValue(
            String(statement[valueRange])
        ) else {
            return nil
        }

        return (
            String(statement[nameRange]),
            value
        )
    }

    private func parseValue(
        _ raw: String
    ) -> PreviewStateValue? {
        if raw == "true" {
            return .bool(true)
        }

        if raw == "false" {
            return .bool(false)
        }

        if raw.first == "\"",
           raw.last == "\"",
           raw.count >= 2 {
            return .string(
                unescapeString(
                    String(raw.dropFirst().dropLast())
                )
            )
        }

        if let value = Double(raw) {
            return .number(value)
        }

        return nil
    }

    /// Splits a constrained Button closure on newlines/semicolons while
    /// respecting quoted strings and line comments.
    private func splitStatements(
        _ body: String
    ) -> [String] {
        var result: [String] = []
        var current = ""
        var index = body.startIndex
        var inString = false
        var escaped = false
        var inLineComment = false

        func flush(_ value: inout String, into result: inout [String]) {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                result.append(trimmed)
            }
            value = ""
        }

        while index < body.endIndex {
            let character = body[index]

            if inLineComment {
                if character == "\n" {
                    inLineComment = false
                    flush(&current, into: &result)
                }
                index = body.index(after: index)
                continue
            }

            if inString {
                current.append(character)

                if escaped {
                    escaped = false
                } else if character == "\\" {
                    escaped = true
                } else if character == "\"" {
                    inString = false
                }

                index = body.index(after: index)
                continue
            }

            if character == "\"" {
                inString = true
                current.append(character)
                index = body.index(after: index)
                continue
            }

            if character == "/" {
                let next = body.index(after: index)
                if next < body.endIndex,
                   body[next] == "/" {
                    inLineComment = true
                    index = body.index(after: next)
                    continue
                }
            }

            if character == "\n" || character == ";" {
                flush(&current, into: &result)
            } else {
                current.append(character)
            }

            index = body.index(after: index)
        }

        flush(&current, into: &result)
        return result
    }

    private func firstMatch(
        pattern: String,
        in text: String
    ) -> NSTextCheckingResult? {
        guard let expression = try? NSRegularExpression(
            pattern: pattern
        ) else {
            return nil
        }

        let range = NSRange(
            text.startIndex..<text.endIndex,
            in: text
        )

        return expression.firstMatch(
            in: text,
            range: range
        )
    }

    private func matchingDelimiter(
        from opening: String.Index,
        open: Character,
        close: Character
    ) throws -> String.Index {
        var index = opening
        var depth = 0

        while index < source.endIndex {
            let character = source[index]

            if character == "\"" {
                index = skipString(from: index)
                continue
            }

            if character == "/",
               let next = nextIndex(after: index),
               source[next] == "/" {
                index = skipLineComment(from: next)
                continue
            }

            if character == open {
                depth += 1
            } else if character == close {
                depth -= 1
                if depth == 0 {
                    return index
                }
            }

            index = source.index(after: index)
        }

        throw PreviewButtonActionError.malformedHeader
    }

    private func skipString(
        from quote: String.Index
    ) -> String.Index {
        var index = source.index(after: quote)
        var escaped = false

        while index < source.endIndex {
            let character = source[index]

            if escaped {
                escaped = false
            } else if character == "\\" {
                escaped = true
            } else if character == "\"" {
                return source.index(after: index)
            }

            index = source.index(after: index)
        }

        return source.endIndex
    }

    private func skipLineComment(
        from secondSlash: String.Index
    ) -> String.Index {
        var index = source.index(after: secondSlash)

        while index < source.endIndex,
              source[index] != "\n" {
            index = source.index(after: index)
        }

        return index
    }

    private func identifierEnd(
        from start: String.Index
    ) -> String.Index {
        var index = start

        while index < source.endIndex,
              isIdentifierPart(source[index]) {
            index = source.index(after: index)
        }

        return index
    }

    private func skipWhitespace(
        at index: inout String.Index
    ) {
        while index < source.endIndex,
              source[index].isWhitespace {
            index = source.index(after: index)
        }
    }

    private func nextIndex(
        after index: String.Index
    ) -> String.Index? {
        let next = source.index(after: index)
        return next < source.endIndex ? next : nil
    }

    private func isIdentifierStart(
        _ character: Character
    ) -> Bool {
        character.isLetter || character == "_"
    }

    private func isIdentifierPart(
        _ character: Character
    ) -> Bool {
        character.isLetter ||
            character.isNumber ||
            character == "_"
    }

    private func unescapeString(
        _ value: String
    ) -> String {
        var result = ""
        var iterator = value.makeIterator()
        var escaping = false

        while let character = iterator.next() {
            if escaping {
                switch character {
                case "n": result.append("\n")
                case "t": result.append("\t")
                case "\"": result.append("\"")
                case "\\": result.append("\\")
                default:
                    result.append("\\")
                    result.append(character)
                }

                escaping = false
                continue
            }

            if character == "\\" {
                escaping = true
            } else {
                result.append(character)
            }
        }

        if escaping {
            result.append("\\")
        }

        return result
    }
}
