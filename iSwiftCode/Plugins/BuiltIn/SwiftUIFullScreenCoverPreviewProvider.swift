import Foundation

/// Adds safe `.fullScreenCover(isPresented:)` preview support above the
/// existing Sheet / Navigation / Interactive preview stack.
///
/// Source closures are parsed into portable Preview IR and are never executed
/// as arbitrary Swift by the preview runtime.
final class SwiftUIFullScreenCoverPreviewProvider: PreviewProvider {
    private let base = SwiftUISheetPreviewProvider()

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
                PreviewFullScreenCoverError.maximumDepthExceeded,
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
        let rewrite: PreviewFullScreenCoverRewrite

        do {
            rewrite = try PreviewFullScreenCoverSourceRewriter(
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
            let covers = try parseCovers(
                rewrite.covers,
                statePrelude: rewrite.statePrelude,
                definitions: document.stateDefinitions,
                originalPath: selectedFile.path,
                request: request,
                presentationDepth: presentationDepth
            )

            return PreviewProviderResult(
                document: PreviewDocument(
                    root: replacingCoverMarkers(
                        in: document.root,
                        covers: covers
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

    private func parseCovers(
        _ specs: [PreviewFullScreenCoverSpec],
        statePrelude: String,
        definitions: [PreviewStateDefinition],
        originalPath: String,
        request: PreviewRequest,
        presentationDepth: Int
    ) throws -> [String: PreviewFullScreenCoverResolved] {
        var result: [String: PreviewFullScreenCoverResolved] = [:]

        for spec in specs {
            guard let definition = definitions.first(
                where: { $0.name == spec.stateName }
            ) else {
                throw PreviewFullScreenCoverError.unknownState(
                    spec.stateName
                )
            }

            guard case .bool = definition.initialValue else {
                throw PreviewFullScreenCoverError.requiresBoolState(
                    spec.stateName
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
                    "Full-screen cover content could not be previewed."

                throw PreviewFullScreenCoverError.invalidContent(
                    stateName: spec.stateName,
                    message: message
                )
            }

            result[spec.marker] = PreviewFullScreenCoverResolved(
                stateName: spec.stateName,
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

    private func replacingCoverMarkers(
        in node: PreviewNode,
        covers: [String: PreviewFullScreenCoverResolved]
    ) -> PreviewNode {
        switch node {
        case .vStack(let children):
            return .vStack(
                children: children.map {
                    replacingCoverMarkers(
                        in: $0,
                        covers: covers
                    )
                }
            )

        case .hStack(let children):
            return .hStack(
                children: children.map {
                    replacingCoverMarkers(
                        in: $0,
                        covers: covers
                    )
                }
            )

        case .zStack(let children):
            return .zStack(
                children: children.map {
                    replacingCoverMarkers(
                        in: $0,
                        covers: covers
                    )
                }
            )

        case .scrollView(let children):
            return .scrollView(
                children: children.map {
                    replacingCoverMarkers(
                        in: $0,
                        covers: covers
                    )
                }
            )

        case .list(let children):
            return .list(
                children: children.map {
                    replacingCoverMarkers(
                        in: $0,
                        covers: covers
                    )
                }
            )

        case .navigationStack(let children):
            return .navigationStack(
                children: children.map {
                    replacingCoverMarkers(
                        in: $0,
                        covers: covers
                    )
                }
            )

        case .navigationLink(
            let title,
            let destination
        ):
            return .navigationLink(
                title: title,
                destination: replacingCoverMarkers(
                    in: destination,
                    covers: covers
                )
            )

        case .modified(let base, let modifiers):
            let resolvedBase = replacingCoverMarkers(
                in: base,
                covers: covers
            )

            let resolvedModifiers = modifiers.map {
                resolving(
                    $0,
                    covers: covers
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

    private func resolving(
        _ modifier: PreviewModifier,
        covers: [String: PreviewFullScreenCoverResolved]
    ) -> PreviewModifier {
        switch modifier {
        case .navigationTitle(let marker):
            guard let cover = covers[marker] else {
                return modifier
            }

            return .fullScreenCover(
                isPresented: PreviewBindingReference(
                    stateName: cover.stateName
                ),
                content: cover.content
            )

        case .sheet(
            let reference,
            let content
        ):
            return .sheet(
                isPresented: reference,
                content: replacingCoverMarkers(
                    in: content,
                    covers: covers
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
                content: replacingCoverMarkers(
                    in: content,
                    covers: covers
                )
            )

        case .fullScreenCover(
            let reference,
            let content
        ):
            return .fullScreenCover(
                isPresented: reference,
                content: replacingCoverMarkers(
                    in: content,
                    covers: covers
                )
            )

        default:
            return modifier
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

private struct PreviewFullScreenCoverResolved {
    let stateName: String
    let content: PreviewNode
}

private struct PreviewFullScreenCoverSpec {
    let marker: String
    let stateName: String
    let contentSource: String
}

private struct PreviewFullScreenCoverRewrite {
    let source: String
    let covers: [PreviewFullScreenCoverSpec]
    let statePrelude: String
}

private enum PreviewFullScreenCoverError: Error {
    case malformedCover
    case malformedContent(String)
    case unknownState(String)
    case requiresBoolState(String)
    case invalidContent(
        stateName: String,
        message: String
    )
    case maximumDepthExceeded
}

extension PreviewFullScreenCoverError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .malformedCover:
            return "Malformed fullScreenCover preview. Use .fullScreenCover(isPresented: $state) { ... }."

        case .malformedContent(let stateName):
            return "Full-screen cover bound to '\(stateName)' has a malformed content closure."

        case .unknownState(let stateName):
            return "Full-screen cover references unknown @State '\(stateName)'."

        case .requiresBoolState(let stateName):
            return "Full-screen cover isPresented binding '\(stateName)' must reference Bool @State."

        case .invalidContent(
            let stateName,
            let message
        ):
            return "Full-screen cover '\(stateName)' content error: \(message)"

        case .maximumDepthExceeded:
            return "Full-screen cover preview exceeded the maximum supported presentation depth."
        }
    }
}

private struct PreviewFullScreenCoverSourceRewriter {
    let source: String

    func rewrite() throws -> PreviewFullScreenCoverRewrite {
        var output = ""
        var covers: [PreviewFullScreenCoverSpec] = []
        var cursor = source.startIndex

        while let start = nextCoverStart(
            from: cursor
        ) {
            output += String(source[cursor..<start])

            let parsed = try parseCover(
                startingAt: start
            )
            let marker = "__ISWIFT_FULL_SCREEN_COVER_\(covers.count)__"

            // Lower through an already-portable string modifier and replace the
            // marker after the lower presentation/navigation providers finish.
            output += ".navigationTitle(\"\(marker)\")"

            covers.append(
                PreviewFullScreenCoverSpec(
                    marker: marker,
                    stateName: parsed.stateName,
                    contentSource: parsed.content
                )
            )

            cursor = parsed.end
        }

        output += String(source[cursor...])

        return PreviewFullScreenCoverRewrite(
            source: output,
            covers: covers,
            statePrelude: statePrelude()
        )
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
        content: String,
        end: String.Index
    ) {
        let nameStart = source.index(after: start)
        var cursor = identifierEnd(from: nameStart)
        skipWhitespace(at: &cursor)

        guard cursor < source.endIndex,
              source[cursor] == "(" else {
            throw PreviewFullScreenCoverError.malformedCover
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
        let stateName = try parseStateName(
            header
        )

        cursor = source.index(after: closeParen)
        skipWhitespace(at: &cursor)

        guard cursor < source.endIndex,
              source[cursor] == "{" else {
            throw PreviewFullScreenCoverError
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
            content,
            source.index(after: closeBrace)
        )
    }

    private func parseStateName(
        _ header: String
    ) throws -> String {
        let pattern =
            #"^\s*isPresented\s*:\s*\$([A-Za-z_][A-Za-z0-9_]*)\s*$"#

        guard let expression = try? NSRegularExpression(
            pattern: pattern
        ) else {
            throw PreviewFullScreenCoverError.malformedCover
        }

        let matchRange = NSRange(
            header.startIndex..<header.endIndex,
            in: header
        )

        guard let match = expression.firstMatch(
            in: header,
            range: matchRange
        ),
        let range = Range(
            match.range(at: 1),
            in: header
        ) else {
            throw PreviewFullScreenCoverError.malformedCover
        }

        return String(header[range])
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

        throw PreviewFullScreenCoverError.malformedCover
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
