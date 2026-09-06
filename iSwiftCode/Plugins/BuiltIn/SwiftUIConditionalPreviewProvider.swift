import Foundation

/// Lowers a deliberately small SwiftUI conditional grammar to portable
/// PreviewNode conditionals. The runtime never executes the source condition.
///
/// Supported first-wave forms:
///
/// ```swift
/// if showingDetails {
///     Text("Details")
/// }
///
/// if !isLoading {
///     Text("Ready")
/// } else {
///     Text("Loading")
/// }
/// ```
///
/// The condition must be one known Bool @State identifier, optionally prefixed
/// with `!`. Branch bodies continue through the complete established provider
/// stack, so Button actions, control styles, and transition modifiers inside a
/// conditional are lowered exactly as they are outside one.
final class SwiftUIConditionalPreviewProvider:
    PreviewProvider {
    private let base =
        SwiftUIControlContentPreviewProvider()

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

        let selected = request.files[selectedIndex]
        let rewrite: PreviewConditionalSourceRewrite

        do {
            rewrite =
                try PreviewConditionalSourceRewriter(
                    source: selected.contents
                ).rewrite()
        } catch {
            return diagnosticResult(
                error,
                filePath: selected.path
            )
        }

        guard !rewrite.markers.isEmpty else {
            return try base.makePreview(request)
        }

        var files = request.files
        files[selectedIndex] = PreviewSourceFile(
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
            try validateConditions(
                rewrite.markers,
                definitions: document.stateDefinitions
            )

            return PreviewProviderResult(
                document: PreviewDocument(
                    root: replacingConditionalMarkers(
                        in: document.root,
                        markers: rewrite.markers
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
                filePath: selected.path
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

    private func validateConditions(
        _ markers: [String: PreviewConditionalMarkerSpec],
        definitions: [PreviewStateDefinition]
    ) throws {
        let definitionsByName = Dictionary(
            uniqueKeysWithValues:
                definitions.map { ($0.name, $0) }
        )

        for spec in markers.values {
            let stateName = spec.condition.stateName

            guard let definition =
                    definitionsByName[stateName] else {
                throw PreviewConditionalSourceError
                    .unknownState(stateName)
            }

            guard case .bool = definition.initialValue else {
                throw PreviewConditionalSourceError
                    .nonBooleanState(stateName)
            }
        }
    }

    private func replacingConditionalMarkers(
        in node: PreviewNode,
        markers: [String: PreviewConditionalMarkerSpec]
    ) -> PreviewNode {
        switch node {
        case .vStack(let children):
            let replaced = children.map {
                replacingConditionalMarkers(
                    in: $0,
                    markers: markers
                )
            }

            if let conditional = conditionalFromWrapper(
                replaced,
                markers: markers
            ) {
                return conditional
            }

            return .vStack(children: replaced)

        case .hStack(let children):
            return .hStack(
                children: children.map {
                    replacingConditionalMarkers(
                        in: $0,
                        markers: markers
                    )
                }
            )

        case .zStack(let children):
            return .zStack(
                children: children.map {
                    replacingConditionalMarkers(
                        in: $0,
                        markers: markers
                    )
                }
            )

        case .scrollView(let children):
            return .scrollView(
                children: children.map {
                    replacingConditionalMarkers(
                        in: $0,
                        markers: markers
                    )
                }
            )

        case .list(let children):
            return .list(
                children: children.map {
                    replacingConditionalMarkers(
                        in: $0,
                        markers: markers
                    )
                }
            )

        case .navigationStack(let children):
            return .navigationStack(
                children: children.map {
                    replacingConditionalMarkers(
                        in: $0,
                        markers: markers
                    )
                }
            )

        case .navigationLink(
            let title,
            let destination
        ):
            return .navigationLink(
                title: title,
                destination: replacingConditionalMarkers(
                    in: destination,
                    markers: markers
                )
            )

        case .conditional(
            let condition,
            let whenTrue,
            let whenFalse
        ):
            return .conditional(
                condition: condition,
                whenTrue: whenTrue.map {
                    replacingConditionalMarkers(
                        in: $0,
                        markers: markers
                    )
                },
                whenFalse: whenFalse.map {
                    replacingConditionalMarkers(
                        in: $0,
                        markers: markers
                    )
                }
            )

        case .modified(
            let baseNode,
            let modifiers
        ):
            return .modified(
                base: replacingConditionalMarkers(
                    in: baseNode,
                    markers: markers
                ),
                modifiers: modifiers.map {
                    replacingConditionalMarkers(
                        in: $0,
                        markers: markers
                    )
                }
            )

        default:
            return node
        }
    }

    private func replacingConditionalMarkers(
        in modifier: PreviewModifier,
        markers: [String: PreviewConditionalMarkerSpec]
    ) -> PreviewModifier {
        switch modifier {
        case .sheet(
            let reference,
            let content
        ):
            return .sheet(
                isPresented: reference,
                content: replacingConditionalMarkers(
                    in: content,
                    markers: markers
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
                content: replacingConditionalMarkers(
                    in: content,
                    markers: markers
                )
            )

        case .fullScreenCover(
            let reference,
            let content
        ):
            return .fullScreenCover(
                isPresented: reference,
                content: replacingConditionalMarkers(
                    in: content,
                    markers: markers
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
                content: replacingConditionalMarkers(
                    in: content,
                    markers: markers
                )
            )

        default:
            return modifier
        }
    }

    private func conditionalFromWrapper(
        _ children: [PreviewNode],
        markers: [String: PreviewConditionalMarkerSpec]
    ) -> PreviewNode? {
        guard let first = children.first,
              case .text(let startMarker) = first,
              let spec = markers[startMarker] else {
            return nil
        }

        guard let separatorIndex =
                children.firstIndex(where: { child in
                    guard case .text(let value) = child else {
                        return false
                    }
                    return value == spec.elseMarker
                }) else {
            return nil
        }

        let trueStart = children.index(after: children.startIndex)
        let trueChildren = Array(
            children[trueStart..<separatorIndex]
        )
        let falseStart = children.index(after: separatorIndex)
        let falseChildren = Array(
            children[falseStart..<children.endIndex]
        )

        return .conditional(
            condition: spec.condition,
            whenTrue: trueChildren,
            whenFalse: falseChildren
        )
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

struct PreviewConditionalMarkerSpec:
    Equatable,
    Sendable {
    let condition: PreviewBooleanCondition
    let elseMarker: String
}

struct PreviewConditionalSourceRewrite:
    Equatable,
    Sendable {
    let source: String
    let markers: [String: PreviewConditionalMarkerSpec]
}

enum PreviewConditionalSourceError:
    Error,
    Equatable,
    Sendable {
    case malformedConditional
    case unknownState(String)
    case nonBooleanState(String)
}

extension PreviewConditionalSourceError:
    LocalizedError {
    var errorDescription: String? {
        switch self {
        case .malformedConditional:
            return "Preview conditional is malformed. Use `if state { ... }` or `if !state { ... }`."
        case .unknownState(let name):
            return "Preview conditional references unknown @State '\(name)'."
        case .nonBooleanState(let name):
            return "Preview conditional requires Bool @State, but '\(name)' is not Bool."
        }
    }
}

struct PreviewConditionalSourceRewriter {
    let source: String

    func rewrite() throws -> PreviewConditionalSourceRewrite {
        var markers: [String: PreviewConditionalMarkerSpec] = [:]
        let rewritten = try rewriteRegion(
            source,
            markers: &markers
        )
        return PreviewConditionalSourceRewrite(
            source: rewritten,
            markers: markers
        )
    }

    private func rewriteRegion(
        _ input: String,
        markers: inout [String: PreviewConditionalMarkerSpec]
    ) throws -> String {
        var output = ""
        var copiedThrough = input.startIndex
        var scan = input.startIndex

        while let start = nextIf(
            in: input,
            from: scan
        ) {
            guard let parsed = try parseConditional(
                in: input,
                startingAt: start
            ) else {
                scan = identifierEnd(
                    in: input,
                    from: start
                )
                continue
            }

            output += String(
                input[copiedThrough..<start]
            )

            let trueBody = try rewriteRegion(
                parsed.trueBody,
                markers: &markers
            )
            let falseBody = try rewriteRegion(
                parsed.falseBody,
                markers: &markers
            )

            let number = markers.count
            let startMarker =
                "__ISWIFT_CONDITIONAL_\(number)__"
            let elseMarker =
                "__ISWIFT_CONDITIONAL_ELSE_\(number)__"

            markers[startMarker] =
                PreviewConditionalMarkerSpec(
                    condition: parsed.condition,
                    elseMarker: elseMarker
                )

            output += """
            VStack {
                Text("\(startMarker)")
                \(trueBody)
                Text("\(elseMarker)")
                \(falseBody)
            }
            """

            copiedThrough = parsed.end
            scan = parsed.end
        }

        output += String(
            input[copiedThrough...]
        )
        return output
    }

    private func parseConditional(
        in input: String,
        startingAt start: String.Index
    ) throws -> PreviewParsedConditional? {
        var cursor = identifierEnd(
            in: input,
            from: start
        )
        skipWhitespace(
            in: input,
            at: &cursor
        )

        let conditionStart = cursor
        while cursor < input.endIndex,
              input[cursor] != "{" {
            if input[cursor] == "\n" ||
               input[cursor] == ";" {
                return nil
            }
            cursor = input.index(after: cursor)
        }

        guard cursor < input.endIndex,
              input[cursor] == "{" else {
            return nil
        }

        let conditionText = String(
            input[conditionStart..<cursor]
        ).trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard let condition = parseCondition(
            conditionText
        ) else {
            return nil
        }

        let trueClose = try matchingDelimiter(
            in: input,
            from: cursor,
            open: "{",
            close: "}"
        )
        let trueBody = String(
            input[
                input.index(after: cursor)..<trueClose
            ]
        )

        var end = input.index(after: trueClose)
        var afterTrue = end
        skipWhitespace(
            in: input,
            at: &afterTrue
        )

        var falseBody = ""

        if startsWithIdentifier(
            "else",
            in: input,
            at: afterTrue
        ) {
            var elseCursor = identifierEnd(
                in: input,
                from: afterTrue
            )
            skipWhitespace(
                in: input,
                at: &elseCursor
            )

            // `else if` remains outside the first-wave grammar. Leaving the
            // whole source construct unchanged is safer than partially
            // lowering it.
            guard elseCursor < input.endIndex,
                  input[elseCursor] == "{" else {
                return nil
            }

            let elseClose = try matchingDelimiter(
                in: input,
                from: elseCursor,
                open: "{",
                close: "}"
            )
            falseBody = String(
                input[
                    input.index(after: elseCursor)..<elseClose
                ]
            )
            end = input.index(after: elseClose)
        }

        return PreviewParsedConditional(
            condition: condition,
            trueBody: trueBody,
            falseBody: falseBody,
            end: end
        )
    }

    private func parseCondition(
        _ raw: String
    ) -> PreviewBooleanCondition? {
        let pattern =
            #"^(!\s*)?([A-Za-z_][A-Za-z0-9_]*)$"#
        guard let regex = try? NSRegularExpression(
            pattern: pattern
        ) else {
            return nil
        }

        let range = NSRange(
            raw.startIndex..<raw.endIndex,
            in: raw
        )
        guard let match = regex.firstMatch(
            in: raw,
            range: range
        ),
        let stateRange = Range(
            match.range(at: 2),
            in: raw
        ) else {
            return nil
        }

        let negated =
            match.range(at: 1).location != NSNotFound

        return PreviewBooleanCondition(
            stateName: String(raw[stateRange]),
            isNegated: negated
        )
    }

    private func nextIf(
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
                if String(input[wordStart..<index]) == "if" {
                    return wordStart
                }
                continue
            }

            index = input.index(after: index)
        }

        return nil
    }

    private func startsWithIdentifier(
        _ identifier: String,
        in input: String,
        at index: String.Index
    ) -> Bool {
        guard index < input.endIndex,
              isIdentifierStart(input[index]) else {
            return false
        }
        let end = identifierEnd(
            in: input,
            from: index
        )
        return String(input[index..<end]) == identifier
    }

    private func identifierEnd(
        in input: String,
        from start: String.Index
    ) -> String.Index {
        var index = start
        while index < input.endIndex,
              isIdentifierCharacter(input[index]) {
            index = input.index(after: index)
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

            index = input.index(after: index)
        }

        throw PreviewConditionalSourceError
            .malformedConditional
    }

    private func skipWhitespace(
        in input: String,
        at index: inout String.Index
    ) {
        while index < input.endIndex,
              input[index].isWhitespace {
            index = input.index(after: index)
        }
    }

    private func skipString(
        in input: String,
        from quote: String.Index
    ) -> String.Index {
        var index = input.index(after: quote)
        var escaped = false

        while index < input.endIndex {
            let character = input[index]
            if escaped {
                escaped = false
            } else if character == "\\" {
                escaped = true
            } else if character == "\"" {
                return input.index(after: index)
            }
            index = input.index(after: index)
        }
        return input.endIndex
    }

    private func skipLineComment(
        in input: String,
        from secondSlash: String.Index
    ) -> String.Index {
        var index = input.index(after: secondSlash)
        while index < input.endIndex,
              input[index] != "\n" {
            index = input.index(after: index)
        }
        return index
    }

    private func nextIndex(
        in input: String,
        after index: String.Index
    ) -> String.Index? {
        let next = input.index(after: index)
        return next < input.endIndex ? next : nil
    }

    private func isIdentifierStart(
        _ character: Character
    ) -> Bool {
        character == "_" || character.isLetter
    }

    private func isIdentifierCharacter(
        _ character: Character
    ) -> Bool {
        isIdentifierStart(character) || character.isNumber
    }
}

private struct PreviewParsedConditional {
    let condition: PreviewBooleanCondition
    let trueBody: String
    let falseBody: String
    let end: String.Index
}
