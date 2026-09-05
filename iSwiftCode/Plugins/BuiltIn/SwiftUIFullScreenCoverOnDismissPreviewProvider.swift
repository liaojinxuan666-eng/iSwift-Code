import Foundation

/// Adds safe `.fullScreenCover(isPresented:onDismiss:)` support above the
/// existing full-screen preview provider.
///
/// The source `onDismiss` closure is lowered to `PreviewActionProgram`. The
/// signed runtime never receives or executes arbitrary Swift source closures.
final class SwiftUIFullScreenCoverOnDismissPreviewProvider: PreviewProvider {
    private let base = SwiftUIFullScreenCoverPreviewProvider()

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
        let rewrite: PreviewFullScreenOnDismissRewrite

        do {
            rewrite = try PreviewFullScreenOnDismissSourceRewriter(
                source: selectedFile.contents
            ).rewrite()
        } catch {
            return diagnosticResult(
                error,
                filePath: selectedFile.path
            )
        }

        guard !rewrite.covers.isEmpty else {
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
            for spec in rewrite.covers {
                try PreviewActionValidator.validate(
                    spec.onDismiss,
                    definitions: document.stateDefinitions
                )
            }

            let specs = Dictionary(
                uniqueKeysWithValues:
                    rewrite.covers.map {
                        ($0.marker, $0)
                    }
            )

            return PreviewProviderResult(
                document: PreviewDocument(
                    root: replacingMarkers(
                        in: document.root,
                        specs: specs
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

    private func replacingMarkers(
        in node: PreviewNode,
        specs: [String: PreviewFullScreenOnDismissSpec]
    ) -> PreviewNode {
        switch node {
        case .vStack(let children):
            return .vStack(
                children: children.map {
                    replacingMarkers(
                        in: $0,
                        specs: specs
                    )
                }
            )

        case .hStack(let children):
            return .hStack(
                children: children.map {
                    replacingMarkers(
                        in: $0,
                        specs: specs
                    )
                }
            )

        case .zStack(let children):
            return .zStack(
                children: children.map {
                    replacingMarkers(
                        in: $0,
                        specs: specs
                    )
                }
            )

        case .scrollView(let children):
            return .scrollView(
                children: children.map {
                    replacingMarkers(
                        in: $0,
                        specs: specs
                    )
                }
            )

        case .list(let children):
            return .list(
                children: children.map {
                    replacingMarkers(
                        in: $0,
                        specs: specs
                    )
                }
            )

        case .navigationStack(let children):
            return .navigationStack(
                children: children.map {
                    replacingMarkers(
                        in: $0,
                        specs: specs
                    )
                }
            )

        case .navigationLink(
            let title,
            let destination
        ):
            return .navigationLink(
                title: title,
                destination: replacingMarkers(
                    in: destination,
                    specs: specs
                )
            )

        case .modified(let base, let modifiers):
            let resolvedBase = replacingMarkers(
                in: base,
                specs: specs
            )
            let nestedModifiers = modifiers.map {
                resolvingNestedContent(
                    $0,
                    specs: specs
                )
            }

            return .modified(
                base: resolvedBase,
                modifiers: collapsingOnDismissMarkers(
                    nestedModifiers,
                    specs: specs
                )
            )

        default:
            return node
        }
    }

    private func resolvingNestedContent(
        _ modifier: PreviewModifier,
        specs: [String: PreviewFullScreenOnDismissSpec]
    ) -> PreviewModifier {
        switch modifier {
        case .sheet(
            let reference,
            let content
        ):
            return .sheet(
                isPresented: reference,
                content: replacingMarkers(
                    in: content,
                    specs: specs
                )
            )

        case .sheetWithOnDismiss(
            let reference,
            let program,
            let content
        ):
            return .sheetWithOnDismiss(
                isPresented: reference,
                onDismiss: program,
                content: replacingMarkers(
                    in: content,
                    specs: specs
                )
            )

        case .fullScreenCover(
            let reference,
            let content
        ):
            return .fullScreenCover(
                isPresented: reference,
                content: replacingMarkers(
                    in: content,
                    specs: specs
                )
            )

        case .fullScreenCoverWithOnDismiss(
            let reference,
            let program,
            let content
        ):
            return .fullScreenCoverWithOnDismiss(
                isPresented: reference,
                onDismiss: program,
                content: replacingMarkers(
                    in: content,
                    specs: specs
                )
            )

        default:
            return modifier
        }
    }

    private func collapsingOnDismissMarkers(
        _ modifiers: [PreviewModifier],
        specs: [String: PreviewFullScreenOnDismissSpec]
    ) -> [PreviewModifier] {
        var result: [PreviewModifier] = []
        var index = 0

        while index < modifiers.count {
            let modifier = modifiers[index]

            if case .fullScreenCover(
                let reference,
                let content
            ) = modifier,
            index + 1 < modifiers.count,
            case .navigationTitle(let marker) = modifiers[index + 1],
            let spec = specs[marker],
            spec.stateName == reference.stateName {
                result.append(
                    .fullScreenCoverWithOnDismiss(
                        isPresented: reference,
                        onDismiss: spec.onDismiss,
                        content: content
                    )
                )
                index += 2
                continue
            }

            result.append(modifier)
            index += 1
        }

        return result
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

private struct PreviewFullScreenOnDismissSpec {
    let marker: String
    let stateName: String
    let onDismiss: PreviewActionProgram
}

private struct PreviewFullScreenOnDismissRewrite {
    let source: String
    let covers: [PreviewFullScreenOnDismissSpec]
}

private enum PreviewFullScreenOnDismissError: Error {
    case malformedCover
    case malformedContent(String)
    case unsupportedOnDismissAction(String)
}

extension PreviewFullScreenOnDismissError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .malformedCover:
            return "Malformed fullScreenCover preview. Use .fullScreenCover(isPresented: $state) { ... } or .fullScreenCover(isPresented: $state, onDismiss: { ... }) { ... }."

        case .malformedContent(let stateName):
            return "Full-screen cover bound to '\(stateName)' has a malformed content closure."

        case .unsupportedOnDismissAction(let statement):
            return "Full-screen cover onDismiss contains an unsupported App Preview action: \(statement)"
        }
    }
}

private struct PreviewFullScreenOnDismissSourceRewriter {
    let source: String

    func rewrite() throws -> PreviewFullScreenOnDismissRewrite {
        var output = source
        var covers: [PreviewFullScreenOnDismissSpec] = []

        while true {
            let scanner = PreviewFullScreenOnDismissScanner(
                source: output
            )

            guard let rewrite = try scanner.rewriteFirst(
                markerIndex: covers.count
            ) else {
                break
            }

            output = rewrite.source
            covers.append(rewrite.spec)
        }

        return PreviewFullScreenOnDismissRewrite(
            source: output,
            covers: covers
        )
    }
}

private struct PreviewFullScreenOnDismissScanner {
    let source: String

    func rewriteFirst(
        markerIndex: Int
    ) throws -> (
        source: String,
        spec: PreviewFullScreenOnDismissSpec
    )? {
        var search = source.startIndex

        while let start = nextCoverStart(
            from: search
        ) {
            let parsed = try parseCover(
                startingAt: start
            )

            guard let onDismiss = parsed.onDismiss else {
                search = parsed.headerEnd
                continue
            }

            let marker =
                "__ISWIFT_FULL_SCREEN_ON_DISMISS_\(markerIndex)__"

            let replacement = """
            .fullScreenCover(isPresented: $\(parsed.stateName)) {
            \(parsed.content)
            }.navigationTitle("\(marker)")
            """

            let rewritten =
                String(source[..<start]) +
                replacement +
                String(source[parsed.end...])

            return (
                rewritten,
                PreviewFullScreenOnDismissSpec(
                    marker: marker,
                    stateName: parsed.stateName,
                    onDismiss: onDismiss
                )
            )
        }

        return nil
    }

    private func nextCoverStart(
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

            if character == "." {
                let nameStart = source.index(after: index)

                if nameStart < source.endIndex,
                   isIdentifierStart(source[nameStart]) {
                    let nameEnd = identifierEnd(
                        from: nameStart
                    )
                    let name = String(
                        source[nameStart..<nameEnd]
                    )

                    if name == "fullScreenCover" {
                        var lookahead = nameEnd
                        skipWhitespace(at: &lookahead)

                        if lookahead < source.endIndex,
                           source[lookahead] == "(" {
                            return index
                        }
                    }
                }
            }

            index = source.index(after: index)
        }

        return nil
    }

    private func parseCover(
        startingAt start: String.Index
    ) throws -> (
        stateName: String,
        onDismiss: PreviewActionProgram?,
        content: String,
        headerEnd: String.Index,
        end: String.Index
    ) {
        let nameStart = source.index(after: start)
        var cursor = identifierEnd(from: nameStart)
        skipWhitespace(at: &cursor)

        guard cursor < source.endIndex,
              source[cursor] == "(" else {
            throw PreviewFullScreenOnDismissError.malformedCover
        }

        let openParen = cursor
        let closeParen = try matchingDelimiter(
            from: openParen,
            open: "(",
            close: ")"
        )
        let headerStart = source.index(after: openParen)
        let header = String(
            source[headerStart..<closeParen]
        )
        let parsedHeader = try parseHeader(header)

        cursor = source.index(after: closeParen)
        let headerEnd = cursor
        skipWhitespace(at: &cursor)

        guard cursor < source.endIndex,
              source[cursor] == "{" else {
            throw PreviewFullScreenOnDismissError
                .malformedContent(parsedHeader.stateName)
        }

        let openBrace = cursor
        let closeBrace = try matchingDelimiter(
            from: openBrace,
            open: "{",
            close: "}"
        )
        let contentStart = source.index(after: openBrace)
        let content = String(
            source[contentStart..<closeBrace]
        )

        return (
            parsedHeader.stateName,
            parsedHeader.onDismiss,
            content,
            headerEnd,
            source.index(after: closeBrace)
        )
    }

    private func parseHeader(
        _ header: String
    ) throws -> (
        stateName: String,
        onDismiss: PreviewActionProgram?
    ) {
        let pattern =
            #"(?s)^\s*isPresented\s*:\s*\$([A-Za-z_][A-Za-z0-9_]*)\s*(?:,\s*onDismiss\s*:\s*\{(.*)\})?\s*$"#

        guard let expression = try? NSRegularExpression(
            pattern: pattern
        ) else {
            throw PreviewFullScreenOnDismissError.malformedCover
        }

        let matchRange = NSRange(
            header.startIndex..<header.endIndex,
            in: header
        )

        guard let match = expression.firstMatch(
            in: header,
            range: matchRange
        ),
        let stateRange = Range(
            match.range(at: 1),
            in: header
        ) else {
            throw PreviewFullScreenOnDismissError.malformedCover
        }

        let stateName = String(
            header[stateRange]
        )

        guard match.range(at: 2).location != NSNotFound,
              let dismissRange = Range(
                  match.range(at: 2),
                  in: header
              ) else {
            return (
                stateName,
                nil
            )
        }

        let dismissSource = String(
            header[dismissRange]
        )

        return (
            stateName,
            try parseDismissProgram(
                dismissSource
            )
        )
    }

    private func parseDismissProgram(
        _ source: String
    ) throws -> PreviewActionProgram {
        let statements = splitActionStatements(
            source
        )

        var actions: [PreviewAction] = []

        for statement in statements {
            if let parsed = parseNumericMutation(
                statement,
                operatorPattern: #"\+="#
            ) {
                actions.append(
                    .add(
                        stateName: parsed.name,
                        amount: parsed.amount
                    )
                )
                continue
            }

            if let parsed = parseNumericMutation(
                statement,
                operatorPattern: #"-="#
            ) {
                actions.append(
                    .add(
                        stateName: parsed.name,
                        amount: -parsed.amount
                    )
                )
                continue
            }

            if let stateName = parseToggleAction(
                statement
            ) {
                actions.append(
                    .toggle(
                        stateName: stateName
                    )
                )
                continue
            }

            if let parsed = parseSetAction(
                statement
            ) {
                actions.append(
                    .set(
                        stateName: parsed.name,
                        value: parsed.value
                    )
                )
                continue
            }

            throw PreviewFullScreenOnDismissError
                .unsupportedOnDismissAction(statement)
        }

        return PreviewActionProgram(
            actions: actions
        )
    }

    private func parseNumericMutation(
        _ statement: String,
        operatorPattern: String
    ) -> (
        name: String,
        amount: Double
    )? {
        let pattern =
            #"^\s*([A-Za-z_][A-Za-z0-9_]*)\s*"# +
            operatorPattern +
            #"\s*(-?(?:\d+(?:\.\d*)?|\.\d+))\s*$"#

        guard let expression = try? NSRegularExpression(
            pattern: pattern
        ) else {
            return nil
        }

        let range = NSRange(
            statement.startIndex..<statement.endIndex,
            in: statement
        )

        guard let match = expression.firstMatch(
            in: statement,
            range: range
        ),
        let nameRange = Range(
            match.range(at: 1),
            in: statement
        ),
        let amountRange = Range(
            match.range(at: 2),
            in: statement
        ),
        let amount = Double(
            statement[amountRange]
        ) else {
            return nil
        }

        return (
            String(statement[nameRange]),
            amount
        )
    }

    private func parseToggleAction(
        _ statement: String
    ) -> String? {
        let pattern =
            #"^\s*([A-Za-z_][A-Za-z0-9_]*)\s*\.\s*toggle\s*\(\s*\)\s*$"#

        guard let expression = try? NSRegularExpression(
            pattern: pattern
        ) else {
            return nil
        }

        let range = NSRange(
            statement.startIndex..<statement.endIndex,
            in: statement
        )

        guard let match = expression.firstMatch(
            in: statement,
            range: range
        ),
        let nameRange = Range(
            match.range(at: 1),
            in: statement
        ) else {
            return nil
        }

        return String(
            statement[nameRange]
        )
    }

    private func parseSetAction(
        _ statement: String
    ) -> (
        name: String,
        value: PreviewStateValue
    )? {
        let pattern =
            #"^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*("(?:\\.|[^"])*"|true|false|-?(?:\d+(?:\.\d*)?|\.\d+))\s*$"#

        guard let expression = try? NSRegularExpression(
            pattern: pattern
        ) else {
            return nil
        }

        let range = NSRange(
            statement.startIndex..<statement.endIndex,
            in: statement
        )

        guard let match = expression.firstMatch(
            in: statement,
            range: range
        ),
        let nameRange = Range(
            match.range(at: 1),
            in: statement
        ),
        let valueRange = Range(
            match.range(at: 2),
            in: statement
        ),
        let value = parseActionValue(
            String(statement[valueRange])
        ) else {
            return nil
        }

        return (
            String(statement[nameRange]),
            value
        )
    }

    private func parseActionValue(
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
                unescapeActionString(
                    String(
                        raw
                            .dropFirst()
                            .dropLast()
                    )
                )
            )
        }

        if let number = Double(raw) {
            return .number(number)
        }

        return nil
    }

    private func splitActionStatements(
        _ body: String
    ) -> [String] {
        var result: [String] = []
        var current = ""
        var index = body.startIndex
        var inString = false
        var escaped = false
        var inLineComment = false

        func flush(
            _ value: inout String,
            into result: inout [String]
        ) {
            let trimmed = value
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

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
                    flush(
                        &current,
                        into: &result
                    )
                }

                index = body.index(
                    after: index
                )
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

                index = body.index(
                    after: index
                )
                continue
            }

            if character == "\"" {
                inString = true
                current.append(character)
                index = body.index(
                    after: index
                )
                continue
            }

            if character == "/" {
                let next = body.index(
                    after: index
                )

                if next < body.endIndex,
                   body[next] == "/" {
                    inLineComment = true
                    index = body.index(
                        after: next
                    )
                    continue
                }
            }

            if character == "\n" ||
                character == ";" {
                flush(
                    &current,
                    into: &result
                )
            } else {
                current.append(character)
            }

            index = body.index(
                after: index
            )
        }

        flush(
            &current,
            into: &result
        )

        return result
    }

    private func unescapeActionString(
        _ value: String
    ) -> String {
        var result = ""
        var iterator = value.makeIterator()
        var escaping = false

        while let character = iterator.next() {
            if escaping {
                switch character {
                case "n":
                    result.append("\n")
                case "t":
                    result.append("\t")
                case "\"":
                    result.append("\"")
                case "\\":
                    result.append("\\")
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

        throw PreviewFullScreenOnDismissError.malformedCover
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
        return next < source.endIndex
            ? next
            : nil
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
}
