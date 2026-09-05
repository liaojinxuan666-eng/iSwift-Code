import Foundation

/// Adds first-class NavigationLink destination previewing on top of the existing
/// interactive/Button preview pipeline.
///
/// The provider lowers a deliberately simple and common SwiftUI form:
///
///     NavigationLink("Details") {
///         DetailsView-like supported preview content
///     }
///
/// into a portable PreviewNode.navigationLink. The destination is parsed through
/// the same safe preview provider stack, so it never executes arbitrary Swift.
final class SwiftUINavigationPreviewProvider: PreviewProvider {
    private let base = SwiftUIButtonActionPreviewProvider()

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
            navigationDepth: 0
        )
    }

    private func makePreview(
        _ request: PreviewRequest,
        navigationDepth: Int
    ) throws -> PreviewProviderResult {
        guard navigationDepth <= 16 else {
            return diagnosticResult(
                PreviewNavigationError.maximumDepthExceeded,
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
        let rewrite: PreviewNavigationRewrite

        do {
            rewrite = try PreviewNavigationSourceRewriter(
                source: selectedFile.contents
            ).rewrite()
        } catch {
            return diagnosticResult(
                error,
                filePath: selectedFile.path
            )
        }

        guard !rewrite.links.isEmpty else {
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
            let destinations = try parseDestinations(
                rewrite.links,
                statePrelude: rewrite.statePrelude,
                originalPath: selectedFile.path,
                request: request,
                navigationDepth: navigationDepth
            )

            return PreviewProviderResult(
                document: PreviewDocument(
                    root: replacingNavigationMarkers(
                        in: document.root,
                        destinations: destinations
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

    private func parseDestinations(
        _ links: [PreviewNavigationLinkSpec],
        statePrelude: String,
        originalPath: String,
        request: PreviewRequest,
        navigationDepth: Int
    ) throws -> [String: PreviewNavigationDestination] {
        var result: [String: PreviewNavigationDestination] = [:]

        for link in links {
            let destinationSource = """
            \(statePrelude)

            VStack {
            \(link.destinationSource)
            }
            """

            let destinationResult = try makePreview(
                PreviewRequest(
                    files: [
                        PreviewSourceFile(
                            path: originalPath,
                            contents: destinationSource
                        )
                    ],
                    entryFilePath: originalPath,
                    platform: request.platform,
                    deviceFamily: request.deviceFamily
                ),
                navigationDepth: navigationDepth + 1
            )

            guard let destinationDocument = destinationResult.document,
                  destinationResult.succeeded else {
                let message = destinationResult.diagnostics
                    .first(where: { $0.severity == .error })?
                    .message ??
                    "NavigationLink destination could not be previewed."
                throw PreviewNavigationError.invalidDestination(
                    title: link.title,
                    message: message
                )
            }

            result[link.marker] = PreviewNavigationDestination(
                title: link.title,
                node: unwrapDestinationWrapper(
                    destinationDocument.root
                )
            )
        }

        return result
    }

    /// The destination is wrapped in a VStack only so multiple top-level
    /// destination views can be parsed by the existing safe provider. If the
    /// wrapper contains exactly one node and has no modifiers, remove it so a
    /// single destination keeps its original layout semantics.
    private func unwrapDestinationWrapper(
        _ node: PreviewNode
    ) -> PreviewNode {
        guard case .vStack(let children) = node,
              children.count == 1,
              let first = children.first else {
            return node
        }

        return first
    }

    private func replacingNavigationMarkers(
        in node: PreviewNode,
        destinations: [String: PreviewNavigationDestination]
    ) -> PreviewNode {
        switch node {
        case .text(let marker):
            guard let destination = destinations[marker] else {
                return node
            }

            return .navigationLink(
                title: destination.title,
                destination: destination.node
            )

        case .vStack(let children):
            return .vStack(
                children: children.map {
                    replacingNavigationMarkers(
                        in: $0,
                        destinations: destinations
                    )
                }
            )

        case .hStack(let children):
            return .hStack(
                children: children.map {
                    replacingNavigationMarkers(
                        in: $0,
                        destinations: destinations
                    )
                }
            )

        case .zStack(let children):
            return .zStack(
                children: children.map {
                    replacingNavigationMarkers(
                        in: $0,
                        destinations: destinations
                    )
                }
            )

        case .scrollView(let children):
            return .scrollView(
                children: children.map {
                    replacingNavigationMarkers(
                        in: $0,
                        destinations: destinations
                    )
                }
            )

        case .list(let children):
            return .list(
                children: children.map {
                    replacingNavigationMarkers(
                        in: $0,
                        destinations: destinations
                    )
                }
            )

        case .navigationStack(let children):
            return .navigationStack(
                children: children.map {
                    replacingNavigationMarkers(
                        in: $0,
                        destinations: destinations
                    )
                }
            )

        case .navigationLink(
            let title,
            let destination
        ):
            return .navigationLink(
                title: title,
                destination: replacingNavigationMarkers(
                    in: destination,
                    destinations: destinations
                )
            )

        case .modified(let base, let modifiers):
            return .modified(
                base: replacingNavigationMarkers(
                    in: base,
                    destinations: destinations
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

private struct PreviewNavigationDestination {
    let title: String
    let node: PreviewNode
}

private struct PreviewNavigationLinkSpec {
    let marker: String
    let title: String
    let destinationSource: String
}

private struct PreviewNavigationRewrite {
    let source: String
    let links: [PreviewNavigationLinkSpec]
    let statePrelude: String
}

private enum PreviewNavigationError: Error {
    case malformedLink
    case malformedDestination(String)
    case maximumDepthExceeded
    case invalidDestination(
        title: String,
        message: String
    )
}

extension PreviewNavigationError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .malformedLink:
            return "Malformed NavigationLink preview. Use NavigationLink(\"Title\") { ... }."

        case .malformedDestination(let title):
            return "NavigationLink '\(title)' has a malformed destination closure."

        case .maximumDepthExceeded:
            return "NavigationLink preview exceeded the maximum supported nesting depth."

        case .invalidDestination(
            let title,
            let message
        ):
            return "NavigationLink '\(title)' destination error: \(message)"
        }
    }
}

private struct PreviewNavigationSourceRewriter {
    let source: String

    func rewrite() throws -> PreviewNavigationRewrite {
        var output = ""
        var links: [PreviewNavigationLinkSpec] = []
        var cursor = source.startIndex

        while let start = nextNavigationLinkStart(
            from: cursor
        ) {
            output += String(source[cursor..<start])

            let parsed = try parseNavigationLink(
                startingAt: start
            )
            let marker = "__ISWIFT_NAV_LINK_\(links.count)__"

            output += "Text(\"\(marker)\")"
            links.append(
                PreviewNavigationLinkSpec(
                    marker: marker,
                    title: parsed.title,
                    destinationSource: parsed.destination
                )
            )
            cursor = parsed.end
        }

        output += String(source[cursor...])

        return PreviewNavigationRewrite(
            source: output,
            links: links,
            statePrelude: statePrelude()
        )
    }

    private func nextNavigationLinkStart(
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

                if word == "NavigationLink" {
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

    private func parseNavigationLink(
        startingAt start: String.Index
    ) throws -> (
        title: String,
        destination: String,
        end: String.Index
    ) {
        var cursor = identifierEnd(from: start)
        skipWhitespace(at: &cursor)

        guard cursor < source.endIndex,
              source[cursor] == "(" else {
            throw PreviewNavigationError.malformedLink
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
            throw PreviewNavigationError
                .malformedDestination(title)
        }

        let openBrace = cursor
        let closeBrace = try matchingDelimiter(
            from: openBrace,
            open: "{",
            close: "}"
        )
        let destinationStart = source.index(after: openBrace)
        let destination = String(
            source[destinationStart..<closeBrace]
        )

        return (
            title,
            destination,
            source.index(after: closeBrace)
        )
    }

    private func parseTitle(
        _ header: String
    ) throws -> String {
        let pattern = #"^\s*"((?:\\.|[^"])*)"\s*$"#

        guard let expression = try? NSRegularExpression(
            pattern: pattern
        ) else {
            throw PreviewNavigationError.malformedLink
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
            throw PreviewNavigationError.malformedLink
        }

        return unescapeString(
            String(header[range])
        )
    }

    /// Preserve the primitive @State declarations already supported by the
    /// preview parser so destination content can reference the same state names.
    private func statePrelude() -> String {
        source
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { line in
                line.trimmingCharacters(in: .whitespaces)
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

        throw PreviewNavigationError.malformedLink
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
