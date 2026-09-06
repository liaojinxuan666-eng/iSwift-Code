import Foundation

final class SwiftUIControlContentPreviewProvider:
    PreviewProvider {
    private let base =
        SwiftUIControlStylePreviewProvider()

    var manifest: PluginManifest {
        base.manifest
    }

    var providerName: String {
        base.providerName
    }

    var supportedPlatforms: Set<PreviewPlatform> {
        base.supportedPlatforms
    }

    func activate(
        context: PluginHostContext
    ) throws {
        try base.activate(context: context)
    }

    func deactivate() {
        base.deactivate()
    }

    func makePreview(
        _ request: PreviewRequest
    ) throws -> PreviewProviderResult {
        guard let selectedIndex =
                selectedFileIndex(in: request) else {
            return try base.makePreview(request)
        }

        let selected =
            request.files[selectedIndex]

        let rewrite:
            PreviewControlContentSourceRewrite

        do {
            rewrite =
                try PreviewControlContentSourceRewriter(
                    source: selected.contents
                ).rewrite()
        } catch {
            return diagnosticResult(
                error,
                filePath: selected.path
            )
        }

        guard rewrite.hasChanges else {
            return try base.makePreview(request)
        }

        var files = request.files
        files[selectedIndex] =
            PreviewSourceFile(
                path: selected.path,
                contents: rewrite.source
            )

        let result = try base.makePreview(
            PreviewRequest(
                files: files,
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
            try validateDisabledStateReferences(
                rewrite.modifierMarkers,
                definitions: document.stateDefinitions
            )
        } catch {
            return diagnosticResult(
                error,
                filePath: selected.path
            )
        }

        return PreviewProviderResult(
            document: PreviewDocument(
                root: replacingMarkers(
                    in: document.root,
                    contentMarkers:
                        rewrite.contentMarkers,
                    modifierMarkers:
                        rewrite.modifierMarkers
                ),
                stateDefinitions:
                    document.stateDefinitions,
                sourceFilePath:
                    document.sourceFilePath,
                title: document.title
            ),
            diagnostics: result.diagnostics
        )
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

    private func validateDisabledStateReferences(
        _ markers:
            [String: PreviewControlModifierMarkerSpec],
        definitions: [PreviewStateDefinition]
    ) throws {
        let byName = Dictionary(
            uniqueKeysWithValues:
                definitions.map {
                    ($0.name, $0)
                }
        )

        for spec in markers.values {
            guard case .disabled(
                .state(let reference)
            ) = spec else {
                continue
            }

            guard let definition =
                    byName[reference.stateName] else {
                throw PreviewControlContentError
                    .unknownDisabledState(
                        reference.stateName
                    )
            }

            guard case .bool =
                    definition.initialValue else {
                throw PreviewControlContentError
                    .nonBooleanDisabledState(
                        reference.stateName
                    )
            }
        }
    }

    private func replacingMarkers(
        in node: PreviewNode,
        contentMarkers:
            [String: PreviewControlContentMarkerSpec],
        modifierMarkers:
            [String: PreviewControlModifierMarkerSpec]
    ) -> PreviewNode {
        switch node {
        case .text(let value):
            guard let marker =
                    contentMarkers[value] else {
                return node
            }

            if case .label(
                let title,
                let systemName
            ) = marker {
                return .label(
                    title: title,
                    systemName: systemName
                )
            }

            return node

        case .button(let title):
            guard let marker =
                    contentMarkers[title] else {
                return node
            }
            return replacingButtonMarker(
                marker,
                program: nil
            )

        case .actionButton(
            let title,
            let program
        ):
            guard let marker =
                    contentMarkers[title] else {
                return node
            }
            return replacingButtonMarker(
                marker,
                program: program
            )

        case .vStack(let children):
            return .vStack(
                children: children.map {
                    replacingMarkers(
                        in: $0,
                        contentMarkers:
                            contentMarkers,
                        modifierMarkers:
                            modifierMarkers
                    )
                }
            )

        case .hStack(let children):
            return .hStack(
                children: children.map {
                    replacingMarkers(
                        in: $0,
                        contentMarkers:
                            contentMarkers,
                        modifierMarkers:
                            modifierMarkers
                    )
                }
            )

        case .zStack(let children):
            return .zStack(
                children: children.map {
                    replacingMarkers(
                        in: $0,
                        contentMarkers:
                            contentMarkers,
                        modifierMarkers:
                            modifierMarkers
                    )
                }
            )

        case .scrollView(let children):
            return .scrollView(
                children: children.map {
                    replacingMarkers(
                        in: $0,
                        contentMarkers:
                            contentMarkers,
                        modifierMarkers:
                            modifierMarkers
                    )
                }
            )

        case .list(let children):
            return .list(
                children: children.map {
                    replacingMarkers(
                        in: $0,
                        contentMarkers:
                            contentMarkers,
                        modifierMarkers:
                            modifierMarkers
                    )
                }
            )

        case .navigationStack(let children):
            return .navigationStack(
                children: children.map {
                    replacingMarkers(
                        in: $0,
                        contentMarkers:
                            contentMarkers,
                        modifierMarkers:
                            modifierMarkers
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
                    contentMarkers:
                        contentMarkers,
                    modifierMarkers:
                        modifierMarkers
                )
            )

        case .modified(
            let baseNode,
            let modifiers
        ):
            return .modified(
                base: replacingMarkers(
                    in: baseNode,
                    contentMarkers:
                        contentMarkers,
                    modifierMarkers:
                        modifierMarkers
                ),
                modifiers: modifiers.map {
                    replacingModifierMarker(
                        $0,
                        markers:
                            modifierMarkers
                    )
                }
            )

        default:
            return node
        }
    }

    private func replacingButtonMarker(
        _ marker: PreviewControlContentMarkerSpec,
        program: PreviewActionProgram?
    ) -> PreviewNode {
        switch marker {
        case .roleButton(
            let title,
            let role
        ):
            if let program {
                return .roleActionButton(
                    title: title,
                    role: role,
                    program: program
                )
            }
            return .roleButton(
                title: title,
                role: role
            )

        case .labelButton(
            let title,
            let systemName,
            let role
        ):
            if let program {
                return .labelActionButton(
                    title: title,
                    systemName: systemName,
                    role: role,
                    program: program
                )
            }
            return .labelButton(
                title: title,
                systemName: systemName,
                role: role
            )

        case .label:
            return .button(
                title: "Unsupported Label marker"
            )
        }
    }

    private func replacingModifierMarker(
        _ modifier: PreviewModifier,
        markers:
            [String: PreviewControlModifierMarkerSpec]
    ) -> PreviewModifier {
        guard case .navigationTitle(
            let title
        ) = modifier,
        let marker = markers[title] else {
            return modifier
        }

        switch marker {
        case .labelStyle(let style):
            return .labelStyle(style)
        case .disabled(let value):
            return .disabled(value)
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

enum PreviewControlContentMarkerSpec:
    Equatable,
    Sendable {
    case label(
        title: String,
        systemName: String
    )
    case roleButton(
        title: String,
        role: PreviewButtonRole
    )
    case labelButton(
        title: String,
        systemName: String,
        role: PreviewButtonRole?
    )
}

enum PreviewControlModifierMarkerSpec:
    Equatable,
    Sendable {
    case labelStyle(PreviewLabelStyle)
    case disabled(PreviewDisabledValue)
}

struct PreviewControlContentSourceRewrite:
    Equatable,
    Sendable {
    let source: String
    let contentMarkers:
        [String: PreviewControlContentMarkerSpec]
    let modifierMarkers:
        [String: PreviewControlModifierMarkerSpec]

    var hasChanges: Bool {
        !contentMarkers.isEmpty ||
        !modifierMarkers.isEmpty
    }
}

enum PreviewControlContentError:
    Error,
    Equatable,
    Sendable {
    case malformedRichButton
    case malformedLabel
    case unknownDisabledState(String)
    case nonBooleanDisabledState(String)
}

extension PreviewControlContentError:
    LocalizedError {
    var errorDescription: String? {
        switch self {
        case .malformedRichButton:
            return "Rich Button preview is malformed."
        case .malformedLabel:
            return "Label preview must use a literal title and systemImage."
        case .unknownDisabledState(let name):
            return "Preview disabled modifier references unknown @State '\(name)'."
        case .nonBooleanDisabledState(let name):
            return "Preview disabled modifier requires Bool @State, but '\(name)' is not Bool."
        }
    }
}

struct PreviewControlContentSourceRewriter {
    let source: String

    func rewrite() throws
        -> PreviewControlContentSourceRewrite {
        var contentMarkers:
            [String: PreviewControlContentMarkerSpec] = [:]

        let buttons = try rewriteRichButtons(
            in: source,
            contentMarkers:
                &contentMarkers
        )

        let labels = try rewriteStandaloneLabels(
            in: buttons,
            contentMarkers:
                &contentMarkers
        )

        var modifierMarkers:
            [String: PreviewControlModifierMarkerSpec] = [:]

        let finalSource = try rewriteModifiers(
            in: labels,
            modifierMarkers:
                &modifierMarkers
        )

        return PreviewControlContentSourceRewrite(
            source: finalSource,
            contentMarkers:
                contentMarkers,
            modifierMarkers:
                modifierMarkers
        )
    }

    private func rewriteRichButtons(
        in input: String,
        contentMarkers:
            inout [String: PreviewControlContentMarkerSpec]
    ) throws -> String {
        var output = ""
        var copiedThrough = input.startIndex
        var scan = input.startIndex

        while let start =
                nextIdentifier(
                    "Button",
                    in: input,
                    from: scan
                ) {
            if let parsed = try parseRichButton(
                in: input,
                startingAt: start
            ) {
                output += String(
                    input[copiedThrough..<start]
                )

                let marker =
                    "__ISWIFT_RICH_BUTTON_\(contentMarkers.count)__"

                contentMarkers[marker] =
                    parsed.spec

                output +=
                    "Button(\"\(marker)\") {" +
                    parsed.actionBody +
                    "}"

                copiedThrough = parsed.end
                scan = parsed.end
            } else {
                scan = identifierEnd(
                    in: input,
                    from: start
                )
            }
        }

        output += String(
            input[copiedThrough...]
        )
        return output
    }

    private func parseRichButton(
        in input: String,
        startingAt start: String.Index
    ) throws -> PreviewParsedRichButton? {
        var cursor = identifierEnd(
            in: input,
            from: start
        )
        skipWhitespace(
            in: input,
            at: &cursor
        )

        var role: PreviewButtonRole?
        var literalTitle: String?

        if cursor < input.endIndex,
           input[cursor] == "(" {
            let closeParen =
                try matchingDelimiter(
                    in: input,
                    from: cursor,
                    open: "(",
                    close: ")"
                )

            let header = String(
                input[
                    input.index(after: cursor)..<closeParen
                ]
            )

            if let parsed =
                    parseTitleRoleHeader(header) {
                literalTitle = parsed.title
                role = parsed.role
            } else if let parsedRole =
                        parseRoleOnlyHeader(header) {
                role = parsedRole
            } else {
                return nil
            }

            cursor = input.index(
                after: closeParen
            )
            skipWhitespace(
                in: input,
                at: &cursor
            )
        }

        guard cursor < input.endIndex,
              input[cursor] == "{" else {
            if role != nil ||
               literalTitle != nil {
                throw PreviewControlContentError
                    .malformedRichButton
            }
            return nil
        }

        let actionClose =
            try matchingDelimiter(
                in: input,
                from: cursor,
                open: "{",
                close: "}"
            )
        let actionBody = String(
            input[
                input.index(after: cursor)..<actionClose
            ]
        )

        var afterAction =
            input.index(after: actionClose)
        skipWhitespace(
            in: input,
            at: &afterAction
        )

        if let literalTitle,
           let role {
            return PreviewParsedRichButton(
                spec: .roleButton(
                    title: literalTitle,
                    role: role
                ),
                actionBody: actionBody,
                end: afterAction
            )
        }

        guard startsWithIdentifier(
            "label",
            in: input,
            at: afterAction
        ) else {
            if role != nil {
                throw PreviewControlContentError
                    .malformedRichButton
            }
            return nil
        }

        var labelCursor = identifierEnd(
            in: input,
            from: afterAction
        )
        skipWhitespace(
            in: input,
            at: &labelCursor
        )

        guard labelCursor < input.endIndex,
              input[labelCursor] == ":" else {
            throw PreviewControlContentError
                .malformedRichButton
        }

        labelCursor = input.index(
            after: labelCursor
        )
        skipWhitespace(
            in: input,
            at: &labelCursor
        )

        guard labelCursor < input.endIndex,
              input[labelCursor] == "{" else {
            throw PreviewControlContentError
                .malformedRichButton
        }

        let labelClose =
            try matchingDelimiter(
                in: input,
                from: labelCursor,
                open: "{",
                close: "}"
            )
        let labelBody = String(
            input[
                input.index(after: labelCursor)..<labelClose
            ]
        )

        guard let label =
                parseLiteralLabel(labelBody) else {
            throw PreviewControlContentError
                .malformedLabel
        }

        return PreviewParsedRichButton(
            spec: .labelButton(
                title: label.title,
                systemName: label.systemName,
                role: role
            ),
            actionBody: actionBody,
            end: input.index(
                after: labelClose
            )
        )
    }

    private func rewriteStandaloneLabels(
        in input: String,
        contentMarkers:
            inout [String: PreviewControlContentMarkerSpec]
    ) throws -> String {
        let pattern =
            #"Label\s*\(\s*"((?:\\.|[^"])*)"\s*,\s*systemImage\s*:\s*"((?:\\.|[^"])*)"\s*\)"#
        let regex =
            try NSRegularExpression(
                pattern: pattern
            )
        let nsInput = input as NSString

        let matches = regex.matches(
            in: input,
            range: NSRange(
                location: 0,
                length: nsInput.length
            )
        ).filter {
            lexicalState(
                in: input,
                atUTF16Location:
                    $0.range.location
            ) == .code
        }

        guard !matches.isEmpty else {
            return input
        }

        let mutable =
            NSMutableString(
                string: input
            )

        for match in matches.reversed() {
            guard match.numberOfRanges >= 3 else {
                continue
            }

            let title = unescapeString(
                nsInput.substring(
                    with: match.range(at: 1)
                )
            )
            let systemName = unescapeString(
                nsInput.substring(
                    with: match.range(at: 2)
                )
            )

            let marker =
                "__ISWIFT_LABEL_\(contentMarkers.count)__"

            contentMarkers[marker] =
                .label(
                    title: title,
                    systemName: systemName
                )

            mutable.replaceCharacters(
                in: match.range,
                with:
                    "Text(\"\(marker)\")"
            )
        }

        return mutable as String
    }

    private func rewriteModifiers(
        in input: String,
        modifierMarkers:
            inout [String: PreviewControlModifierMarkerSpec]
    ) throws -> String {
        var replacements:
            [PreviewControlModifierReplacement] = []
        let nsInput = input as NSString

        let labelRegex =
            try NSRegularExpression(
                pattern:
                    #"\.labelStyle\s*\(\s*\.(titleAndIcon|titleOnly|iconOnly)\s*\)"#
            )

        for match in labelRegex.matches(
            in: input,
            range: NSRange(
                location: 0,
                length: nsInput.length
            )
        ) {
            guard match.numberOfRanges >= 2,
                  lexicalState(
                    in: input,
                    atUTF16Location:
                        match.range.location
                  ) == .code else {
                continue
            }

            let raw = nsInput.substring(
                with: match.range(at: 1)
            )
            guard let style =
                    PreviewLabelStyle(
                        rawValue: raw
                    ) else {
                continue
            }

            let marker =
                "__ISWIFT_CONTROL_CONTENT_MODIFIER_\(modifierMarkers.count)__"

            modifierMarkers[marker] =
                .labelStyle(style)

            replacements.append(
                PreviewControlModifierReplacement(
                    range: match.range,
                    text:
                        ".navigationTitle(\"\(marker)\")"
                )
            )
        }

        let disabledRegex =
            try NSRegularExpression(
                pattern:
                    #"\.disabled\s*\(\s*(true|false|[A-Za-z_][A-Za-z0-9_]*)\s*\)"#
            )

        for match in disabledRegex.matches(
            in: input,
            range: NSRange(
                location: 0,
                length: nsInput.length
            )
        ) {
            guard match.numberOfRanges >= 2,
                  lexicalState(
                    in: input,
                    atUTF16Location:
                        match.range.location
                  ) == .code else {
                continue
            }

            let raw = nsInput.substring(
                with: match.range(at: 1)
            )
            let value: PreviewDisabledValue

            if raw == "true" {
                value = .literal(true)
            } else if raw == "false" {
                value = .literal(false)
            } else {
                value = .state(
                    PreviewBindingReference(
                        stateName: raw
                    )
                )
            }

            let marker =
                "__ISWIFT_CONTROL_CONTENT_MODIFIER_\(modifierMarkers.count)__"

            modifierMarkers[marker] =
                .disabled(value)

            replacements.append(
                PreviewControlModifierReplacement(
                    range: match.range,
                    text:
                        ".navigationTitle(\"\(marker)\")"
                )
            )
        }

        guard !replacements.isEmpty else {
            return input
        }

        let mutable =
            NSMutableString(
                string: input
            )

        for replacement in replacements.sorted(
            by: {
                $0.range.location >
                    $1.range.location
            }
        ) {
            mutable.replaceCharacters(
                in: replacement.range,
                with: replacement.text
            )
        }

        return mutable as String
    }

    private func parseTitleRoleHeader(
        _ header: String
    ) -> (
        title: String,
        role: PreviewButtonRole
    )? {
        let pattern =
            #"^\s*"((?:\\.|[^"])*)"\s*,\s*role\s*:\s*\.(destructive|cancel)\s*$"#

        guard let match = firstMatch(
            pattern: pattern,
            in: header
        ),
        let titleRange = Range(
            match.range(at: 1),
            in: header
        ),
        let roleRange = Range(
            match.range(at: 2),
            in: header
        ),
        let role = PreviewButtonRole(
            rawValue:
                String(header[roleRange])
        ) else {
            return nil
        }

        return (
            unescapeString(
                String(header[titleRange])
            ),
            role
        )
    }

    private func parseRoleOnlyHeader(
        _ header: String
    ) -> PreviewButtonRole? {
        let pattern =
            #"^\s*role\s*:\s*\.(destructive|cancel)\s*$"#

        guard let match = firstMatch(
            pattern: pattern,
            in: header
        ),
        let roleRange = Range(
            match.range(at: 1),
            in: header
        ) else {
            return nil
        }

        return PreviewButtonRole(
            rawValue:
                String(header[roleRange])
        )
    }

    private func parseLiteralLabel(
        _ body: String
    ) -> (
        title: String,
        systemName: String
    )? {
        let pattern =
            #"^\s*Label\s*\(\s*"((?:\\.|[^"])*)"\s*,\s*systemImage\s*:\s*"((?:\\.|[^"])*)"\s*\)\s*$"#

        guard let match = firstMatch(
            pattern: pattern,
            in: body
        ),
        let titleRange = Range(
            match.range(at: 1),
            in: body
        ),
        let systemRange = Range(
            match.range(at: 2),
            in: body
        ) else {
            return nil
        }

        return (
            unescapeString(
                String(body[titleRange])
            ),
            unescapeString(
                String(body[systemRange])
            )
        )
    }

    private func nextIdentifier(
        _ identifier: String,
        in input: String,
        from start: String.Index
    ) -> String.Index? {
        var index = start

        while index < input.endIndex {
            let character = input[index]

            if character == "\"" {
                index = skipString(
                    in: input,
                    from: index
                )
                continue
            }

            if character == "/",
               let next = nextIndex(
                    in: input,
                    after: index
               ),
               input[next] == "/" {
                index = skipLineComment(
                    in: input,
                    from: next
                )
                continue
            }

            if isIdentifierStart(character) {
                let wordStart = index
                index = identifierEnd(
                    in: input,
                    from: index
                )

                if String(
                    input[wordStart..<index]
                ) == identifier {
                    return wordStart
                }
                continue
            }

            index = input.index(
                after: index
            )
        }

        return nil
    }

    private func startsWithIdentifier(
        _ identifier: String,
        in input: String,
        at index: String.Index
    ) -> Bool {
        guard index < input.endIndex,
              isIdentifierStart(
                input[index]
              ) else {
            return false
        }

        let end = identifierEnd(
            in: input,
            from: index
        )
        return String(
            input[index..<end]
        ) == identifier
    }

    private func identifierEnd(
        in input: String,
        from start: String.Index
    ) -> String.Index {
        var index = start
        while index < input.endIndex,
              isIdentifierCharacter(
                input[index]
              ) {
            index = input.index(
                after: index
            )
        }
        return index
    }

    private func matchingDelimiter(
        in input: String,
        from opening: String.Index,
        open: Character,
        close: Character
    ) throws -> String.Index {
        var index = opening
        var depth = 0

        while index < input.endIndex {
            let character = input[index]

            if character == "\"" {
                index = skipString(
                    in: input,
                    from: index
                )
                continue
            }

            if character == "/",
               let next = nextIndex(
                    in: input,
                    after: index
               ),
               input[next] == "/" {
                index = skipLineComment(
                    in: input,
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

            index = input.index(
                after: index
            )
        }

        throw PreviewControlContentError
            .malformedRichButton
    }

    private func skipWhitespace(
        in input: String,
        at index: inout String.Index
    ) {
        while index < input.endIndex,
              input[index].isWhitespace {
            index = input.index(
                after: index
            )
        }
    }

    private func skipString(
        in input: String,
        from quote: String.Index
    ) -> String.Index {
        var index = input.index(
            after: quote
        )
        var escaped = false

        while index < input.endIndex {
            let character = input[index]

            if escaped {
                escaped = false
            } else if character == "\\" {
                escaped = true
            } else if character == "\"" {
                return input.index(
                    after: index
                )
            }

            index = input.index(
                after: index
            )
        }

        return input.endIndex
    }

    private func skipLineComment(
        in input: String,
        from secondSlash: String.Index
    ) -> String.Index {
        var index = input.index(
            after: secondSlash
        )

        while index < input.endIndex,
              input[index] != "\n" {
            index = input.index(
                after: index
            )
        }

        return index
    }

    private func nextIndex(
        in input: String,
        after index: String.Index
    ) -> String.Index? {
        let next = input.index(
            after: index
        )
        return next < input.endIndex
            ? next
            : nil
    }

    private func isIdentifierStart(
        _ character: Character
    ) -> Bool {
        character == "_" ||
        character.isLetter
    }

    private func isIdentifierCharacter(
        _ character: Character
    ) -> Bool {
        isIdentifierStart(character) ||
        character.isNumber
    }

    private func firstMatch(
        pattern: String,
        in input: String
    ) -> NSTextCheckingResult? {
        guard let regex =
                try? NSRegularExpression(
                    pattern: pattern
                ) else {
            return nil
        }

        return regex.firstMatch(
            in: input,
            range: NSRange(
                input.startIndex..<input.endIndex,
                in: input
            )
        )
    }

    private func unescapeString(
        _ value: String
    ) -> String {
        value
            .replacingOccurrences(
                of: #"\""#,
                with: #"""#
            )
            .replacingOccurrences(
                of: #"\\n"#,
                with: "\n"
            )
            .replacingOccurrences(
                of: #"\\t"#,
                with: "\t"
            )
            .replacingOccurrences(
                of: #"\\\\"#,
                with: #"\"#
            )
    }

    private func lexicalState(
        in input: String,
        atUTF16Location location: Int
    ) -> PreviewControlContentLexicalState {
        let nsInput = input as NSString
        var index = 0
        var inString = false
        var escaped = false
        var inLineComment = false

        while index < location,
              index < nsInput.length {
            let scalar =
                nsInput.character(at: index)

            if inLineComment {
                if scalar == 10 {
                    inLineComment = false
                }
                index += 1
                continue
            }

            if inString {
                if escaped {
                    escaped = false
                } else if scalar == 92 {
                    escaped = true
                } else if scalar == 34 {
                    inString = false
                }
                index += 1
                continue
            }

            if scalar == 34 {
                inString = true
                index += 1
                continue
            }

            if scalar == 47,
               index + 1 < nsInput.length,
               nsInput.character(
                    at: index + 1
               ) == 47 {
                inLineComment = true
                index += 2
                continue
            }

            index += 1
        }

        if inLineComment {
            return .lineComment
        }
        if inString {
            return .string
        }
        return .code
    }
}

private struct PreviewParsedRichButton {
    let spec: PreviewControlContentMarkerSpec
    let actionBody: String
    let end: String.Index
}

private struct PreviewControlModifierReplacement {
    let range: NSRange
    let text: String
}

private enum PreviewControlContentLexicalState {
    case code
    case string
    case lineComment
}
