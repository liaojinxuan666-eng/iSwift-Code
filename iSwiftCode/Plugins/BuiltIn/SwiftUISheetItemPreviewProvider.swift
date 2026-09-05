import Foundation

/// Adds constrained source support for `.sheet(item:)` above the existing
/// presentation provider stack.
///
/// Optional primitive state remains portable Preview IR. The signed runtime
/// bridges that state to SwiftUI's native item-driven sheet presentation.
final class SwiftUISheetItemPreviewProvider: PreviewProvider {
    private let base = SwiftUIFullScreenCoverOnDismissPreviewProvider()

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
                PreviewSheetItemError.maximumDepthExceeded,
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
        let rewrite: PreviewSheetItemRewrite

        do {
            rewrite = try PreviewSheetItemSourceRewriter(
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
        _ specs: [PreviewSheetItemSpec],
        statePrelude: String,
        definitions: [PreviewStateDefinition],
        originalPath: String,
        request: PreviewRequest,
        presentationDepth: Int
    ) throws -> [String: PreviewSheetItemResolved] {
        var result: [String: PreviewSheetItemResolved] = [:]

        for spec in specs {
            guard let definition = definitions.first(
                where: { $0.name == spec.stateName }
            ) else {
                throw PreviewSheetItemError.unknownState(
                    spec.stateName
                )
            }

            guard isOptionalPrimitive(
                definition.initialValue
            ) else {
                throw PreviewSheetItemError.requiresOptionalPrimitive(
                    spec.stateName
                )
            }

            let rewrittenContent = replacingItemReferences(
                in: spec.contentSource,
                itemName: spec.itemName,
                stateName: spec.stateName
            )

            let contentSource = """
            \(statePrelude)

            VStack {
            \(rewrittenContent)
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
                    "Sheet item content could not be previewed."

                throw PreviewSheetItemError.invalidContent(
                    stateName: spec.stateName,
                    message: message
                )
            }

            result[spec.marker] = PreviewSheetItemResolved(
                stateName: spec.stateName,
                content: unwrapContentWrapper(
                    contentDocument.root
                )
            )
        }

        return result
    }

    private func isOptionalPrimitive(
        _ value: PreviewStateValue
    ) -> Bool {
        switch value {
        case .optionalString,
             .optionalBool,
             .optionalNumber:
            return true

        default:
            return false
        }
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

    /// Rebinds the source closure parameter to the actual portable state name.
    /// This preserves safe `Text(item)` / interpolation support without ever
    /// executing the source closure.
    private func replacingItemReferences(
        in content: String,
        itemName: String,
        stateName: String
    ) -> String {
        let outsideStrings = replacingIdentifierOutsideStrings(
            in: content,
            identifier: itemName,
            replacement: stateName
        )

        return outsideStrings.replacingOccurrences(
            of: "\\(\(itemName))",
            with: "\\(\(stateName))"
        )
    }

    private func replacingIdentifierOutsideStrings(
        in source: String,
        identifier: String,
        replacement: String
    ) -> String {
        var output = ""
        var index = source.startIndex

        while index < source.endIndex {
            let character = source[index]

            if character == "\"" {
                let end = stringEnd(
                    in: source,
                    from: index
                )
                output += String(source[index..<end])
                index = end
                continue
            }

            if character == "/",
               let next = nextIndex(
                    in: source,
                    after: index
               ),
               source[next] == "/" {
                let end = lineCommentEnd(
                    in: source,
                    from: next
                )
                output += String(source[index..<end])
                index = end
                continue
            }

            if isIdentifierStart(character) {
                let end = identifierEnd(
                    in: source,
                    from: index
                )
                let word = String(source[index..<end])
                output += word == identifier
                    ? replacement
                    : word
                index = end
                continue
            }

            output.append(character)
            index = source.index(after: index)
        }

        return output
    }

    private func replacingSheetMarkers(
        in node: PreviewNode,
        sheets: [String: PreviewSheetItemResolved]
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
            return .modified(
                base: replacingSheetMarkers(
                    in: base,
                    sheets: sheets
                ),
                modifiers: modifiers.map {
                    resolving(
                        $0,
                        sheets: sheets
                    )
                }
            )

        default:
            return node
        }
    }

    private func resolving(
        _ modifier: PreviewModifier,
        sheets: [String: PreviewSheetItemResolved]
    ) -> PreviewModifier {
        switch modifier {
        case .navigationTitle(let marker):
            guard let sheet = sheets[marker] else {
                return modifier
            }

            return .sheet(
                isPresented: PreviewBindingReference(
                    stateName: sheet.stateName
                ),
                content: sheet.content
            )

        case .sheet(
            let reference,
            let content
        ):
            return .sheet(
                isPresented: reference,
                content: replacingSheetMarkers(
                    in: content,
                    sheets: sheets
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
                content: replacingSheetMarkers(
                    in: content,
                    sheets: sheets
                )
            )

        case .fullScreenCover(
            let reference,
            let content
        ):
            return .fullScreenCover(
                isPresented: reference,
                content: replacingSheetMarkers(
                    in: content,
                    sheets: sheets
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
                content: replacingSheetMarkers(
                    in: content,
                    sheets: sheets
                )
            )

        default:
            return modifier
        }
    }

    private func stringEnd(
        in source: String,
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

    private func lineCommentEnd(
        in source: String,
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
        in source: String,
        from start: String.Index
    ) -> String.Index {
        var index = start

        while index < source.endIndex,
              isIdentifierPart(source[index]) {
            index = source.index(after: index)
        }

        return index
    }

    private func nextIndex(
        in source: String,
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

private struct PreviewSheetItemResolved {
    let stateName: String
    let content: PreviewNode
}

private struct PreviewSheetItemSpec {
    let marker: String
    let stateName: String
    let itemName: String
    let contentSource: String
}

private struct PreviewSheetItemRewrite {
    let source: String
    let sheets: [PreviewSheetItemSpec]
    let statePrelude: String
}

private enum PreviewSheetItemError: Error {
    case malformedHeader
    case malformedContent(String)
    case unknownState(String)
    case requiresOptionalPrimitive(String)
    case invalidContent(
        stateName: String,
        message: String
    )
    case maximumDepthExceeded
}

extension PreviewSheetItemError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .malformedHeader:
            return "Malformed sheet item preview. Use .sheet(item: $state) { item in ... }."

        case .malformedContent(let stateName):
            return "Sheet item bound to '\(stateName)' must use a single closure parameter, for example { item in ... }."

        case .unknownState(let stateName):
            return "Sheet item references unknown @State '\(stateName)'."

        case .requiresOptionalPrimitive(let stateName):
            return "Sheet item binding '\(stateName)' must reference typed optional String, Bool, Int, Double, or Float @State initialized to nil."

        case .invalidContent(
            let stateName,
            let message
        ):
            return "Sheet item '\(stateName)' content error: \(message)"

        case .maximumDepthExceeded:
            return "Sheet item preview exceeded the maximum supported presentation depth."
        }
    }
}

private struct PreviewSheetItemSourceRewriter {
    let source: String

    func rewrite() throws -> PreviewSheetItemRewrite {
        var output = source
        var sheets: [PreviewSheetItemSpec] = []

        while true {
            let scanner = PreviewSheetItemScanner(
                source: output
            )

            guard let rewrite = try scanner.rewriteFirst(
                markerIndex: sheets.count
            ) else {
                break
            }

            output = rewrite.source
            sheets.append(rewrite.spec)
        }

        return PreviewSheetItemRewrite(
            source: output,
            sheets: sheets,
            statePrelude: statePrelude()
        )
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
}

private struct PreviewSheetItemScanner {
    let source: String

    func rewriteFirst(
        markerIndex: Int
    ) throws -> (
        source: String,
        spec: PreviewSheetItemSpec
    )? {
        var search = source.startIndex

        while let start = nextSheetStart(
            from: search
        ) {
            let parsed = try parseSheet(
                startingAt: start
            )

            if let parsed {
                let marker =
                    "__ISWIFT_SHEET_ITEM_\(markerIndex)__"

                let replacement =
                    ".navigationTitle(\"\(marker)\")"

                let rewritten =
                    String(source[..<start]) +
                    replacement +
                    String(source[parsed.end...])

                return (
                    rewritten,
                    PreviewSheetItemSpec(
                        marker: marker,
                        stateName: parsed.stateName,
                        itemName: parsed.itemName,
                        contentSource: parsed.content
                    )
                )
            }

            search = source.index(after: start)
        }

        return nil
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
        itemName: String,
        content: String,
        end: String.Index
    )? {
        let nameStart = source.index(after: start)
        var cursor = identifierEnd(from: nameStart)
        skipWhitespace(at: &cursor)

        guard cursor < source.endIndex,
              source[cursor] == "(" else {
            return nil
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

        guard header.range(
            of: #"^\s*item\s*:"#,
            options: .regularExpression
        ) != nil else {
            return nil
        }

        let stateName = try parseStateName(
            header
        )

        cursor = source.index(after: closeParen)
        skipWhitespace(at: &cursor)

        guard cursor < source.endIndex,
              source[cursor] == "{" else {
            throw PreviewSheetItemError
                .malformedContent(stateName)
        }

        let openBrace = cursor
        let closeBrace = try matchingDelimiter(
            from: openBrace,
            open: "{",
            close: "}"
        )
        let bodyStart = source.index(after: openBrace)
        let body = String(
            source[bodyStart..<closeBrace]
        )
        let closure = try parseClosureBody(
            body,
            stateName: stateName
        )

        return (
            stateName,
            closure.itemName,
            closure.content,
            source.index(after: closeBrace)
        )
    }

    private func parseStateName(
        _ header: String
    ) throws -> String {
        let pattern =
            #"^\s*item\s*:\s*\$([A-Za-z_][A-Za-z0-9_]*)\s*$"#

        guard let match = firstMatch(
            pattern: pattern,
            in: header
        ),
        let range = Range(
            match.range(at: 1),
            in: header
        ) else {
            throw PreviewSheetItemError.malformedHeader
        }

        return String(header[range])
    }

    private func parseClosureBody(
        _ body: String,
        stateName: String
    ) throws -> (
        itemName: String,
        content: String
    ) {
        let pattern =
            #"^\s*([A-Za-z_][A-Za-z0-9_]*)\s+in\b"#

        guard let match = firstMatch(
            pattern: pattern,
            in: body
        ),
        let itemRange = Range(
            match.range(at: 1),
            in: body
        ),
        let fullRange = Range(
            match.range(at: 0),
            in: body
        ) else {
            throw PreviewSheetItemError
                .malformedContent(stateName)
        }

        return (
            String(body[itemRange]),
            String(body[fullRange.upperBound...])
        )
    }

    private func firstMatch(
        pattern: String,
        in text: String
    ) -> NSTextCheckingResult? {
        guard let expression =
            try? NSRegularExpression(
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

        throw PreviewSheetItemError.malformedHeader
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
