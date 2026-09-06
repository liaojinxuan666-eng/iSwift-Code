import Foundation

/// Adds portable SwiftUI control-style modifiers on top of the established
/// motion and Identifiable preview stack.
final class SwiftUIControlStylePreviewProvider:
    PreviewProvider {
    private let base =
        SwiftUIAnimationTransitionPreviewProvider()

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
        try base.activate(
            context: context
        )
    }

    func deactivate() {
        base.deactivate()
    }

    func makePreview(
        _ request: PreviewRequest
    ) throws -> PreviewProviderResult {
        guard let selectedIndex =
                selectedFileIndex(
                    in: request
                ) else {
            return try base.makePreview(
                request
            )
        }

        let selected =
            request.files[selectedIndex]

        let rewrite:
            PreviewControlStyleSourceRewrite

        do {
            rewrite =
                try PreviewControlStyleSourceRewriter(
                    source:
                        selected.contents
                ).rewrite()
        } catch {
            return diagnosticResult(
                error,
                filePath:
                    selected.path
            )
        }

        guard !rewrite.markers.isEmpty else {
            return try base.makePreview(
                request
            )
        }

        var rewrittenFiles =
            request.files

        rewrittenFiles[selectedIndex] =
            PreviewSourceFile(
                path: selected.path,
                contents: rewrite.source
            )

        let result = try base.makePreview(
            PreviewRequest(
                files:
                    rewrittenFiles,
                entryFilePath:
                    request.entryFilePath,
                platform:
                    request.platform,
                deviceFamily:
                    request.deviceFamily
            )
        )

        guard let document =
                result.document,
              result.succeeded else {
            return result
        }

        return PreviewProviderResult(
            document:
                PreviewDocument(
                    root:
                        replacingStyleMarkers(
                            in:
                                document.root,
                            markers:
                                rewrite.markers
                        ),
                    stateDefinitions:
                        document.stateDefinitions,
                    sourceFilePath:
                        document.sourceFilePath,
                    title:
                        document.title
                ),
            diagnostics:
                result.diagnostics
        )
    }

    private func selectedFileIndex(
        in request: PreviewRequest
    ) -> Int? {
        if let entry =
                request.entryFilePath,
           let index =
                request.files.firstIndex(
                    where: {
                        $0.path == entry
                    }
                ) {
            return index
        }

        return request.files.firstIndex {
            $0.path
                .lowercased()
                .hasSuffix(".swift")
        }
    }

    private func replacingStyleMarkers(
        in node: PreviewNode,
        markers:
            [String: PreviewControlStyleMarkerSpec]
    ) -> PreviewNode {
        switch node {
        case .vStack(let children):
            return .vStack(
                children:
                    children.map {
                        replacingStyleMarkers(
                            in: $0,
                            markers: markers
                        )
                    }
            )

        case .hStack(let children):
            return .hStack(
                children:
                    children.map {
                        replacingStyleMarkers(
                            in: $0,
                            markers: markers
                        )
                    }
            )

        case .zStack(let children):
            return .zStack(
                children:
                    children.map {
                        replacingStyleMarkers(
                            in: $0,
                            markers: markers
                        )
                    }
            )

        case .scrollView(let children):
            return .scrollView(
                children:
                    children.map {
                        replacingStyleMarkers(
                            in: $0,
                            markers: markers
                        )
                    }
            )

        case .list(let children):
            return .list(
                children:
                    children.map {
                        replacingStyleMarkers(
                            in: $0,
                            markers: markers
                        )
                    }
            )

        case .navigationStack(let children):
            return .navigationStack(
                children:
                    children.map {
                        replacingStyleMarkers(
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
                destination:
                    replacingStyleMarkers(
                        in: destination,
                        markers: markers
                    )
            )

        case .modified(
            let baseNode,
            let modifiers
        ):
            return .modified(
                base:
                    replacingStyleMarkers(
                        in:
                            baseNode,
                        markers:
                            markers
                    ),
                modifiers:
                    modifiers.map {
                        replacingStyleMarker(
                            in: $0,
                            markers: markers
                        )
                    }
            )

        default:
            return node
        }
    }

    private func replacingStyleMarker(
        in modifier: PreviewModifier,
        markers:
            [String: PreviewControlStyleMarkerSpec]
    ) -> PreviewModifier {
        guard case .navigationTitle(
            let title
        ) = modifier,
        let spec = markers[title] else {
            return modifier
        }

        switch spec {
        case .buttonStyle(let style):
            return .buttonStyle(style)

        case .textFieldStyle(let style):
            return .textFieldStyle(style)

        case .pickerStyle(let style):
            return .pickerStyle(style)

        case .toggleStyle(let style):
            return .toggleStyle(style)

        case .controlSize(let size):
            return .controlSize(size)

        case .tint(let color):
            return .tint(color)
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
                    filePath:
                        filePath
                )
            ]
        )
    }
}

enum PreviewControlStyleMarkerSpec:
    Equatable,
    Sendable {
    case buttonStyle(PreviewButtonStyle)
    case textFieldStyle(PreviewTextFieldStyle)
    case pickerStyle(PreviewPickerStyle)
    case toggleStyle(PreviewToggleStyle)
    case controlSize(PreviewControlSize)
    case tint(PreviewColor)
}

struct PreviewControlStyleSourceRewrite:
    Equatable,
    Sendable {
    let source: String
    let markers:
        [String: PreviewControlStyleMarkerSpec]
}

struct PreviewControlStyleSourceRewriter {
    let source: String

    func rewrite() throws
        -> PreviewControlStyleSourceRewrite {
        let matches =
            try allMatches()

        guard !matches.isEmpty else {
            return PreviewControlStyleSourceRewrite(
                source: source,
                markers: [:]
            )
        }

        var markers:
            [String: PreviewControlStyleMarkerSpec] = [:]
        var replacements:
            [PreviewControlStyleReplacement] = []

        for item in matches.sorted(
            by: {
                $0.range.location <
                    $1.range.location
            }
        ) {
            let marker =
                "__ISWIFT_CONTROL_STYLE_\(markers.count)__"

            markers[marker] =
                item.spec

            replacements.append(
                PreviewControlStyleReplacement(
                    range: item.range,
                    replacement:
                        ".navigationTitle(\"\(marker)\")"
                )
            )
        }

        let mutable =
            NSMutableString(
                string: source
            )

        for replacement in replacements
            .sorted(
                by: {
                    $0.range.location >
                        $1.range.location
                }
            ) {
            mutable.replaceCharacters(
                in:
                    replacement.range,
                with:
                    replacement.replacement
            )
        }

        return PreviewControlStyleSourceRewrite(
            source:
                mutable as String,
            markers:
                markers
        )
    }

    private func allMatches() throws
        -> [PreviewControlStyleMatch] {
        var matches:
            [PreviewControlStyleMatch] = []

        matches += try enumStyleMatches(
            modifier: "buttonStyle",
            values: [
                "automatic",
                "plain",
                "borderless",
                "bordered",
                "borderedProminent"
            ]
        ) { raw in
            PreviewButtonStyle(
                rawValue: raw
            ).map(
                PreviewControlStyleMarkerSpec
                    .buttonStyle
            )
        }

        matches += try enumStyleMatches(
            modifier: "textFieldStyle",
            values: [
                "automatic",
                "plain",
                "roundedBorder"
            ]
        ) { raw in
            PreviewTextFieldStyle(
                rawValue: raw
            ).map(
                PreviewControlStyleMarkerSpec
                    .textFieldStyle
            )
        }

        matches += try enumStyleMatches(
            modifier: "pickerStyle",
            values: [
                "automatic",
                "menu",
                "segmented",
                "wheel",
                "inline"
            ]
        ) { raw in
            PreviewPickerStyle(
                rawValue: raw
            ).map(
                PreviewControlStyleMarkerSpec
                    .pickerStyle
            )
        }

        matches += try enumStyleMatches(
            modifier: "toggleStyle",
            values: [
                "automatic",
                "switch",
                "button"
            ]
        ) { raw in
            PreviewToggleStyle(
                rawValue: raw
            ).map(
                PreviewControlStyleMarkerSpec
                    .toggleStyle
            )
        }

        matches += try enumStyleMatches(
            modifier: "controlSize",
            values: [
                "mini",
                "small",
                "regular",
                "large"
            ]
        ) { raw in
            PreviewControlSize(
                rawValue: raw
            ).map(
                PreviewControlStyleMarkerSpec
                    .controlSize
            )
        }

        matches += try enumStyleMatches(
            modifier: "tint",
            values:
                PreviewColor.allCases
                    .map(\.rawValue)
        ) { raw in
            PreviewColor(
                rawValue: raw
            ).map(
                PreviewControlStyleMarkerSpec
                    .tint
            )
        }

        return deduplicated(
            matches
        )
    }

    private func enumStyleMatches(
        modifier: String,
        values: [String],
        make:
            (String) -> PreviewControlStyleMarkerSpec?
    ) throws
        -> [PreviewControlStyleMatch] {
        let choices =
            values
                .map {
                    NSRegularExpression
                        .escapedPattern(
                            for: $0
                        )
                }
                .joined(separator: "|")

        let pattern =
            #"\."# +
            NSRegularExpression
                .escapedPattern(
                    for: modifier
                ) +
            #"\s*\(\s*\.("# +
            choices +
            #")\s*\)"#

        let regex =
            try NSRegularExpression(
                pattern: pattern
            )
        let nsSource =
            source as NSString

        return regex.matches(
            in: source,
            range: NSRange(
                location: 0,
                length:
                    nsSource.length
            )
        ).compactMap { match in
            guard match.numberOfRanges >= 2,
                  isCodeLocation(
                    match.range.location
                  ) else {
                return nil
            }

            let raw =
                nsSource.substring(
                    with:
                        match.range(at: 1)
                )

            guard let spec =
                    make(raw) else {
                return nil
            }

            return PreviewControlStyleMatch(
                range:
                    match.range,
                spec:
                    spec
            )
        }
    }

    private func deduplicated(
        _ matches:
            [PreviewControlStyleMatch]
    ) -> [PreviewControlStyleMatch] {
        var seen = Set<String>()

        return matches.filter {
            let key =
                "\($0.range.location):\($0.range.length)"

            guard !seen.contains(key) else {
                return false
            }

            seen.insert(key)
            return true
        }
    }

    private func isCodeLocation(
        _ location: Int
    ) -> Bool {
        lexicalState(
            at: location
        ) == .code
    }

    private func lexicalState(
        at location: Int
    ) -> PreviewControlStyleLexicalState {
        let nsSource =
            source as NSString

        var index = 0
        var inString = false
        var escaped = false
        var inLineComment = false

        while index < location,
              index < nsSource.length {
            let scalar =
                nsSource.character(
                    at: index
                )

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
               index + 1 <
                    nsSource.length,
               nsSource.character(
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

private struct PreviewControlStyleMatch {
    let range: NSRange
    let spec: PreviewControlStyleMarkerSpec
}

private struct PreviewControlStyleReplacement {
    let range: NSRange
    let replacement: String
}

private enum PreviewControlStyleLexicalState {
    case code
    case string
    case lineComment
}
