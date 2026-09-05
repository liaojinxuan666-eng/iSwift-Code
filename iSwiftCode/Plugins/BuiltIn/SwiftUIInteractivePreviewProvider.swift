import Foundation

/// Interactive SwiftUI preview provider used by the app runtime.
///
/// The structural provider remains the compatibility baseline. This provider
/// adds source-to-IR lowering for interactive controls that need information
/// the baseline parser does not yet preserve, then delegates all remaining
/// SwiftUI parsing to `SwiftUIPreviewProvider`.
final class SwiftUIInteractivePreviewProvider: PreviewProvider {
    private let base = SwiftUIPreviewProvider()

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

        let rewrite: PreviewPickerRewrite

        do {
            rewrite = try PreviewPickerSourceRewriter(
                source: selectedFile.contents
            ).rewrite()
        } catch {
            return diagnosticResult(
                error,
                filePath: selectedFile.path
            )
        }

        guard !rewrite.pickers.isEmpty else {
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
            let pickers = try validatedPickers(
                rewrite.pickers,
                stateDefinitions:
                    document.stateDefinitions
            )

            return PreviewProviderResult(
                document: PreviewDocument(
                    root: replacingPickerMarkers(
                        in: document.root,
                        pickers: pickers
                    ),
                    stateDefinitions:
                        document.stateDefinitions,
                    sourceFilePath:
                        document.sourceFilePath,
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
            $0.path.lowercased()
                .hasSuffix(".swift")
        }
    }

    private func validatedPickers(
        _ pickers: [PreviewPickerSpec],
        stateDefinitions:
            [PreviewStateDefinition]
    ) throws -> [String: PreviewPickerSpec] {
        let states = Dictionary(
            uniqueKeysWithValues:
                stateDefinitions.map {
                    ($0.name, $0.initialValue)
                }
        )

        var result: [String: PreviewPickerSpec] = [:]

        for picker in pickers {
            guard let selectionValue =
                states[picker.selectionState] else {
                throw PreviewPickerError
                    .unknownSelectionState(
                        picker.selectionState
                    )
            }

            guard !picker.options.isEmpty else {
                throw PreviewPickerError
                    .missingOptions(picker.title)
            }

            for option in picker.options {
                guard sameValueKind(
                    selectionValue,
                    option.value
                ) else {
                    throw PreviewPickerError
                        .tagTypeMismatch(
                            picker: picker.title,
                            state:
                                picker.selectionState
                        )
                }
            }

            result[picker.marker] = picker
        }

        return result
    }

    private func sameValueKind(
        _ lhs: PreviewStateValue,
        _ rhs: PreviewStateValue
    ) -> Bool {
        switch (lhs, rhs) {
        case (.string, .string),
             (.bool, .bool),
             (.number, .number):
            return true

        default:
            return false
        }
    }

    private func replacingPickerMarkers(
        in node: PreviewNode,
        pickers: [String: PreviewPickerSpec]
    ) -> PreviewNode {
        switch node {
        case .text(let marker):
            guard let picker = pickers[marker] else {
                return node
            }

            return .picker(
                title: picker.title,
                selection:
                    PreviewBindingReference(
                        stateName:
                            picker.selectionState
                    ),
                options: picker.options
            )

        case .vStack(let children):
            return .vStack(
                children: children.map {
                    replacingPickerMarkers(
                        in: $0,
                        pickers: pickers
                    )
                }
            )

        case .hStack(let children):
            return .hStack(
                children: children.map {
                    replacingPickerMarkers(
                        in: $0,
                        pickers: pickers
                    )
                }
            )

        case .zStack(let children):
            return .zStack(
                children: children.map {
                    replacingPickerMarkers(
                        in: $0,
                        pickers: pickers
                    )
                }
            )

        case .scrollView(let children):
            return .scrollView(
                children: children.map {
                    replacingPickerMarkers(
                        in: $0,
                        pickers: pickers
                    )
                }
            )

        case .list(let children):
            return .list(
                children: children.map {
                    replacingPickerMarkers(
                        in: $0,
                        pickers: pickers
                    )
                }
            )

        case .navigationStack(let children):
            return .navigationStack(
                children: children.map {
                    replacingPickerMarkers(
                        in: $0,
                        pickers: pickers
                    )
                }
            )

        case .modified(
            let base,
            let modifiers
        ):
            return .modified(
                base: replacingPickerMarkers(
                    in: base,
                    pickers: pickers
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
                    message:
                        error.localizedDescription,
                    filePath: filePath
                )
            ]
        )
    }
}

private struct PreviewPickerSpec {
    let marker: String
    let title: String
    let selectionState: String
    let options: [PreviewPickerOption]
}

private struct PreviewPickerRewrite {
    let source: String
    let pickers: [PreviewPickerSpec]
}

private enum PreviewPickerError: Error {
    case malformedHeader
    case malformedBody(String)
    case missingOptions(String)
    case unknownSelectionState(String)
    case tagTypeMismatch(
        picker: String,
        state: String
    )
}

extension PreviewPickerError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .malformedHeader:
            return
                "Malformed Picker preview. Use Picker(\"Title\", selection: $state) { ... }."

        case .malformedBody(let title):
            return
                "Picker '\(title)' must use static Text(...).tag(...) options in App Preview."

        case .missingOptions(let title):
            return
                "Picker '\(title)' contains no previewable tagged options."

        case .unknownSelectionState(let state):
            return
                "Picker selection references unknown @State '\(state)'."

        case .tagTypeMismatch(
            let picker,
            let state
        ):
            return
                "Picker '\(picker)' tag values must match the value type of @State '\(state)'."
        }
    }
}

private struct PreviewPickerSourceRewriter {
    let source: String

    func rewrite() throws -> PreviewPickerRewrite {
        var output = ""
        var pickers: [PreviewPickerSpec] = []
        var cursor = source.startIndex

        while let start = nextPickerStart(
            from: cursor
        ) {
            output += String(
                source[cursor..<start]
            )

            let parsed = try parsePicker(
                startingAt: start,
                number: pickers.count
            )

            output +=
                "Text(\"\(parsed.spec.marker)\")"

            pickers.append(parsed.spec)
            cursor = parsed.end
        }

        output += String(source[cursor...])

        return PreviewPickerRewrite(
            source: output,
            pickers: pickers
        )
    }

    private func nextPickerStart(
        from start: String.Index
    ) -> String.Index? {
        var index = start

        while index < source.endIndex {
            let character = source[index]

            if character == "\"" {
                index = skipString(
                    from: index
                )
                continue
            }

            if character == "/",
               let next = nextIndex(after: index),
               source[next] == "/" {
                index = skipLineComment(
                    from: next
                )
                continue
            }

            if isIdentifierStart(character) {
                let wordStart = index
                index = identifierEnd(
                    from: index
                )

                let word = String(
                    source[wordStart..<index]
                )

                if word == "Picker" {
                    var cursor = index
                    skipWhitespace(
                        at: &cursor
                    )

                    if cursor < source.endIndex,
                       source[cursor] == "(" {
                        return wordStart
                    }
                }

                continue
            }

            index = source.index(
                after: index
            )
        }

        return nil
    }

    private func parsePicker(
        startingAt start: String.Index,
        number: Int
    ) throws -> (
        spec: PreviewPickerSpec,
        end: String.Index
    ) {
        var cursor = start

        cursor = identifierEnd(
            from: cursor
        )
        skipWhitespace(at: &cursor)

        guard cursor < source.endIndex,
              source[cursor] == "(" else {
            throw PreviewPickerError
                .malformedHeader
        }

        let openParen = cursor
        let closeParen = try matchingDelimiter(
            from: openParen,
            open: "(",
            close: ")"
        )

        let headerStart = source.index(
            after: openParen
        )
        let header = String(
            source[
                headerStart..<closeParen
            ]
        )

        let parsedHeader =
            try parseHeader(header)

        cursor = source.index(
            after: closeParen
        )
        skipWhitespace(at: &cursor)

        guard cursor < source.endIndex,
              source[cursor] == "{" else {
            throw PreviewPickerError
                .malformedHeader
        }

        let openBrace = cursor
        let closeBrace = try matchingDelimiter(
            from: openBrace,
            open: "{",
            close: "}"
        )

        let bodyStart = source.index(
            after: openBrace
        )
        let body = String(
            source[
                bodyStart..<closeBrace
            ]
        )

        let options = try parseOptions(
            body,
            pickerTitle:
                parsedHeader.title
        )

        let marker =
            "__ISWIFT_PICKER_\(number)__"

        return (
            PreviewPickerSpec(
                marker: marker,
                title: parsedHeader.title,
                selectionState:
                    parsedHeader.selection,
                options: options
            ),
            source.index(
                after: closeBrace
            )
        )
    }

    private func parseHeader(
        _ header: String
    ) throws -> (
        title: String,
        selection: String
    ) {
        let pattern =
            #"^\s*"((?:\\.|[^"])*)"\s*,\s*selection\s*:\s*\$([A-Za-z_][A-Za-z0-9_]*)\s*$"#

        guard let match = firstMatch(
            pattern: pattern,
            in: header
        ),
        let titleRange = Range(
            match.range(at: 1),
            in: header
        ),
        let selectionRange = Range(
            match.range(at: 2),
            in: header
        ) else {
            throw PreviewPickerError
                .malformedHeader
        }

        return (
            unescapeString(
                String(
                    header[titleRange]
                )
            ),
            String(
                header[selectionRange]
            )
        )
    }

    private func parseOptions(
        _ body: String,
        pickerTitle: String
    ) throws -> [PreviewPickerOption] {
        let pattern =
            #"Text\s*\(\s*"((?:\\.|[^"])*)"\s*\)\s*\.tag\s*\(\s*("(?:\\.|[^"])*"|true|false|-?(?:\d+(?:\.\d*)?|\.\d+))\s*\)"#

        let expression = try NSRegularExpression(
            pattern: pattern
        )
        let range = NSRange(
            body.startIndex..<body.endIndex,
            in: body
        )
        let matches = expression.matches(
            in: body,
            range: range
        )

        guard !matches.isEmpty else {
            throw PreviewPickerError
                .malformedBody(pickerTitle)
        }

        return try matches.map { match in
            guard let titleRange = Range(
                match.range(at: 1),
                in: body
            ),
            let valueRange = Range(
                match.range(at: 2),
                in: body
            ) else {
                throw PreviewPickerError
                    .malformedBody(
                        pickerTitle
                    )
            }

            let title = unescapeString(
                String(body[titleRange])
            )
            let rawValue = String(
                body[valueRange]
            )

            guard let value = parseValue(
                rawValue
            ) else {
                throw PreviewPickerError
                    .malformedBody(
                        pickerTitle
                    )
            }

            return PreviewPickerOption(
                title: title,
                value: value
            )
        }
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
                    String(
                        raw.dropFirst()
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
                index = skipString(
                    from: index
                )
                continue
            }

            if character == "/",
               let next = nextIndex(after: index),
               source[next] == "/" {
                index = skipLineComment(
                    from: next
                )
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

            index = source.index(
                after: index
            )
        }

        throw PreviewPickerError
            .malformedHeader
    }

    private func skipString(
        from quote: String.Index
    ) -> String.Index {
        var index = source.index(
            after: quote
        )
        var escaped = false

        while index < source.endIndex {
            let character = source[index]

            if escaped {
                escaped = false
            } else if character == "\\" {
                escaped = true
            } else if character == "\"" {
                return source.index(
                    after: index
                )
            }

            index = source.index(
                after: index
            )
        }

        return source.endIndex
    }

    private func skipLineComment(
        from secondSlash: String.Index
    ) -> String.Index {
        var index = source.index(
            after: secondSlash
        )

        while index < source.endIndex,
              source[index] != "\n" {
            index = source.index(
                after: index
            )
        }

        return index
    }

    private func identifierEnd(
        from start: String.Index
    ) -> String.Index {
        var index = start

        while index < source.endIndex,
              isIdentifierPart(
                source[index]
              ) {
            index = source.index(
                after: index
            )
        }

        return index
    }

    private func skipWhitespace(
        at index: inout String.Index
    ) {
        while index < source.endIndex,
              source[index].isWhitespace {
            index = source.index(
                after: index
            )
        }
    }

    private func nextIndex(
        after index: String.Index
    ) -> String.Index? {
        let next = source.index(
            after: index
        )
        return next < source.endIndex
            ? next
            : nil
    }

    private func isIdentifierStart(
        _ character: Character
    ) -> Bool {
        character.isLetter ||
            character == "_"
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
        var iterator =
            value.makeIterator()
        var escaping = false

        while let character =
            iterator.next() {
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
}
