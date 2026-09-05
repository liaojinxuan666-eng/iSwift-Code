import Foundation

/// Adds safe `.sheet(isPresented:)` presentation on top of the existing
/// navigation / interactive preview pipeline.
///
/// Sheet source is lowered into a portable PreviewModifier.sheet. The signed
/// runtime turns only that IR into native SwiftUI presentation; arbitrary sheet
/// source closures are parsed, never executed directly.
final class SwiftUISheetPreviewProvider: PreviewProvider {
    private let base = SwiftUINavigationPreviewProvider()

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
        try makePreview(
            request,
            presentationDepth: 0
        )
    }

    private func makePreview(
        _ request: PreviewRequest,
        presentationDepth: Int
    ) throws -> PreviewProviderResult {
        guard presentationDepth <= 12 else {
            return diagnosticResult(
                PreviewSheetError.maximumDepthExceeded,
                filePath: request.entryFilePath ??
                    request.files.first?.path ??
                    "Preview.swift"
            )
        }

        guard let selectedIndex = selectedFileIndex(
            in: request
        ) else {
            return try base.makePreview(request)
        }

        let selectedFile = request.files[selectedIndex]
        let rewrite: PreviewSheetRewrite

        do {
            rewrite = try PreviewSheetSourceRewriter(
                source: selectedFile.contents
            ).rewrite()
        } catch {
            return diagnosticResult(
                error,
                filePath: selectedFile.path
            )
        }

        guard !rewrite.sheets.isEmpty else {
            return try base.makePreview(request)
        }

        var rewrittenFiles = request.files
        rewrittenFiles[selectedIndex] = PreviewSourceFile(
            path: selectedFile.path,
            contents: rewrite.source
        )

        let rootResult = try base.makePreview(
            PreviewRequest(
                files: rewrittenFiles,
                entryFilePath: request.entryFilePath,
                platform: request.platform,
                deviceFamily: request.deviceFamily
            )
        )

        guard let document = rootResult.document,
              rootResult.succeeded else {
            return rootResult
        }

        do {
            let sheets = try parseSheets(
                rewrite.sheets,
                statePrelude: rewrite.statePrelude,
                definitions: document.stateDefinitions,
                originalPath: selectedFile.path,
                request: request,
                presentationDepth: presentationDepth
            )

            return PreviewProviderResult(
                document: PreviewDocument(
                    root: replacingSheetMarkers(
                        in: document.root,
                        sheets: sheets
                    ),
                    stateDefinitions: document.stateDefinitions,
                    sourceFilePath: document.sourceFilePath,
                    title: document.title
                ),
                diagnostics: rootResult.diagnostics
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

    private func parseSheets(
        _ specs: [PreviewSheetSpec],
        statePrelude: String,
        definitions: [PreviewStateDefinition],
        originalPath: String,
        request: PreviewRequest,
        presentationDepth: Int
    ) throws -> [String: PreviewSheetResolved] {
        var result: [String: PreviewSheetResolved] = [:]

        for spec in specs {
            guard let definition = definitions.first(
                where: { $0.name == spec.stateName }
            ) else {
                throw PreviewSheetError.unknownState(
                    spec.stateName
                )
            }

            guard case .bool = definition.initialValue else {
                throw PreviewSheetError.requiresBoolState(
                    spec.stateName
                )
            }

            if let onDismiss = spec.onDismiss {
                try PreviewActionValidator.validate(
                    onDismiss,
                    definitions: definitions
                )
            }

            let contentSource = """
            \(statePrelude)

            VStack {
            \(spec.contentSource)
            }
            """

            let contentResult = try makePreview(
                PreviewRequest(
                    files: [
                        PreviewSourceFile(
                            path: originalPath,
                            contents: contentSource
                        )
                    ],
                    entryFilePath: originalPath,
                    platform: request.platform,
                    deviceFamily: request.deviceFamily
                ),
                presentationDepth: presentationDepth + 1
            )

            guard let contentDocument = contentResult.document,
                  contentResult.succeeded else {
                let message = contentResult.diagnostics
                    .first(where: { $0.severity == .error })?
                    .message ??
                    "Sheet content could not be previewed."

                throw PreviewSheetError.invalidContent(
                    stateName: spec.stateName,
                    message: message
                )
            }

            result[spec.marker] = PreviewSheetResolved(
                stateName: spec.stateName,
                onDismiss: spec.onDismiss,
                content: unwrapContentWrapper(
                    contentDocument.root
                )
            )
        }

        return result
    }

    private func unwrapContentWrapper(
        _ node: PreviewNode
    ) -> PreviewNode {
        guard case .vStack(let children) = node,
              children.count == 1,
              let first = children.first else {
            return node
        }

        return first
    }

    private func replacingSheetMarkers(
        in node: PreviewNode,
        sheets: [String: PreviewSheetResolved]
    ) -> PreviewNode {
        switch node {
        case .vStack(let children):
            return .vStack(
                children: children.map {
                    replacingSheetMarkers(
                        in: $0,
                        sheets: sheets
                    )
                }
            )

        case .hStack(let children):
            return .hStack(
                children: children.map {
                    replacingSheetMarkers(
                        in: $0,
                        sheets: sheets
                    )
                }
            )

        case .zStack(let children):
            return .zStack(
                children: children.map {
                    replacingSheetMarkers(
                        in: $0,
                        sheets: sheets
                    )
                }
            )

        case .scrollView(let children):
            return .scrollView(
                children: children.map {
                    replacingSheetMarkers(
                        in: $0,
                        sheets: sheets
                    )
                }
            )

        case .list(let children):
            return .list(
                children: children.map {
                    replacingSheetMarkers(
                        in: $0,
                        sheets: sheets
                    )
                }
            )

        case .navigationStack(let children):
            return .navigationStack(
                children: children.map {
                    replacingSheetMarkers(
                        in: $0,
                        sheets: sheets
                    )
                }
            )

        case .navigationLink(
            let title,
            let destination
        ):
            return .navigationLink(
                title: title,
                destination: replacingSheetMarkers(
                    in: destination,
                    sheets: sheets
                )
            )

        case .modified(let base, let modifiers):
            let resolvedBase = replacingSheetMarkers(
                in: base,
                sheets: sheets
            )

            let resolvedModifiers = modifiers.map {
                modifier -> PreviewModifier in

                guard case .navigationTitle(let marker) = modifier,
                      let sheet = sheets[marker] else {
                    return modifier
                }

                let reference = PreviewBindingReference(
                    stateName: sheet.stateName
                )

                if let onDismiss = sheet.onDismiss {
                    return .sheetWithOnDismiss(
                        isPresented: reference,
                        onDismiss: onDismiss,
                        content: sheet.content
                    )
                }

                return .sheet(
                    isPresented: reference,
                    content: sheet.content
                )
            }

            return .modified(
                base: resolvedBase,
                modifiers: resolvedModifiers
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

private struct PreviewSheetResolved {
    let stateName: String
    let onDismiss: PreviewActionProgram?
    let content: PreviewNode
}

private struct PreviewSheetSpec {
    let marker: String
    let stateName: String
    let onDismiss: PreviewActionProgram?
    let contentSource: String
}

private struct PreviewSheetRewrite {
    let source: String
    let sheets: [PreviewSheetSpec]
    let statePrelude: String
}

private enum PreviewSheetError: Error {
    case malformedSheet
    case malformedContent(String)
    case unknownState(String)
    case requiresBoolState(String)
    case unsupportedOnDismissAction(String)
    case invalidContent(
        stateName: String,
        message: String
    )
    case maximumDepthExceeded
}

extension PreviewSheetError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .malformedSheet:
            return "Malformed sheet preview. Use .sheet(isPresented: $state) { ... } or .sheet(isPresented: $state, onDismiss: { ... }) { ... }."

        case .malformedContent(let stateName):
            return "Sheet bound to '\(stateName)' has a malformed content closure."

        case .unknownState(let stateName):
            return "Sheet references unknown @State '\(stateName)'."

        case .requiresBoolState(let stateName):
            return "Sheet isPresented binding '\(stateName)' must reference Bool @State."

        case .unsupportedOnDismissAction(let statement):
            return "Sheet onDismiss contains an unsupported App Preview action: \(statement)"

        case .invalidContent(
            let stateName,
            let message
        ):
            return "Sheet '\(stateName)' content error: \(message)"

        case .maximumDepthExceeded:
            return "Sheet preview exceeded the maximum supported presentation depth."
        }
    }
}

private struct PreviewSheetSourceRewriter {
    let source: String

    func rewrite() throws -> PreviewSheetRewrite {
        var output = ""
        var sheets: [PreviewSheetSpec] = []
        var cursor = source.startIndex

        while let start = nextSheetStart(
            from: cursor
        ) {
            output += String(source[cursor..<start])

            let parsed = try parseSheet(
                startingAt: start
            )
            let marker = "__ISWIFT_SHEET_\(sheets.count)__"

            // navigationTitle is already a portable string modifier in the
            // lower provider stack. It acts only as an internal marker here and
            // is replaced with PreviewModifier.sheet before returning the IR.
            output += ".navigationTitle(\"\(marker)\")"

            sheets.append(
                PreviewSheetSpec(
                    marker: marker,
                    stateName: parsed.stateName,
                    onDismiss: parsed.onDismiss,
                    contentSource: parsed.content
                )
            )

            cursor = parsed.end
        }

        output += String(source[cursor...])

        return PreviewSheetRewrite(
            source: output,
            sheets: sheets,
            statePrelude: statePrelude()
        )
    }

    private func nextSheetStart(
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

                    if name == "sheet" {
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

    private func parseSheet(
        startingAt start: String.Index
    ) throws -> (
        stateName: String,
        onDismiss: PreviewActionProgram?,
        content: String,
        end: String.Index
    ) {
        let nameStart = source.index(after: start)
        var cursor = identifierEnd(from: nameStart)
        skipWhitespace(at: &cursor)

        guard cursor < source.endIndex,
              source[cursor] == "(" else {
            throw PreviewSheetError.malformedSheet
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
        let parsedHeader = try parseHeader(
            header
        )
        let stateName = parsedHeader.stateName

        cursor = source.index(after: closeParen)
        skipWhitespace(at: &cursor)

        guard cursor < source.endIndex,
              source[cursor] == "{" else {
            throw PreviewSheetError
                .malformedContent(stateName)
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
            stateName,
            parsedHeader.onDismiss,
            content,
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
            throw PreviewSheetError.malformedSheet
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
            throw PreviewSheetError.malformedSheet
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

            throw PreviewSheetError.unsupportedOnDismissAction(
                statement
            )
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

    private func statePrelude() -> String {
        source
            .split(
                separator: "\n",
                omittingEmptySubsequences: false
            )
            .map(String.init)
            .filter { line in
                line.trimmingCharacters(
                    in: .whitespaces
                )
                .hasPrefix("@State ")
            }
            .joined(separator: "\n")
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

        throw PreviewSheetError.malformedSheet
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
