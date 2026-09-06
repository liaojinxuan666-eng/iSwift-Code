import Foundation

/// Adds a portable first motion layer without changing the generic project or
/// workspace core.
///
/// Supported source forms:
///
/// ```swift
/// .animation(.easeInOut, value: count)
/// .animation(.easeInOut(duration: 0.25), value: count)
/// .animation(.linear, value: count)
/// .animation(.spring(), value: count)
///
/// .transition(.opacity)
/// .transition(.scale)
/// .transition(.slide)
/// .transition(.move(edge: .leading))
/// ```
///
/// Motion calls are replaced with temporary parser-safe navigation-title
/// markers before the existing provider stack runs. The markers are converted
/// back to portable PreviewModifier values before the document reaches the
/// runtime.
final class SwiftUIAnimationTransitionPreviewProvider:
    PreviewProvider {
    private let base =
        SwiftUIIdentifiableItemValidationPreviewProvider()

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
            PreviewMotionSourceRewrite

        do {
            rewrite =
                try PreviewMotionSourceRewriter(
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

        do {
            try validateAnimationStateReferences(
                rewrite.markers,
                definitions:
                    document.stateDefinitions
            )

            return PreviewProviderResult(
                document:
                    PreviewDocument(
                        root:
                            replacingMotionMarkers(
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
        } catch {
            return diagnosticResult(
                error,
                filePath:
                    selected.path
            )
        }
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

    private func validateAnimationStateReferences(
        _ markers:
            [String: PreviewMotionMarkerSpec],
        definitions:
            [PreviewStateDefinition]
    ) throws {
        let stateNames =
            Set(
                definitions.map(
                    \.name
                )
            )

        for spec in markers.values {
            guard case .animation(
                _,
                let stateName
            ) = spec else {
                continue
            }

            guard stateNames.contains(
                stateName
            ) else {
                throw
                    PreviewMotionSourceError
                        .unknownAnimationState(
                            stateName
                        )
            }
        }
    }

    private func replacingMotionMarkers(
        in node: PreviewNode,
        markers:
            [String: PreviewMotionMarkerSpec]
    ) -> PreviewNode {
        switch node {
        case .vStack(let children):
            return .vStack(
                children:
                    children.map {
                        replacingMotionMarkers(
                            in: $0,
                            markers: markers
                        )
                    }
            )

        case .hStack(let children):
            return .hStack(
                children:
                    children.map {
                        replacingMotionMarkers(
                            in: $0,
                            markers: markers
                        )
                    }
            )

        case .zStack(let children):
            return .zStack(
                children:
                    children.map {
                        replacingMotionMarkers(
                            in: $0,
                            markers: markers
                        )
                    }
            )

        case .scrollView(let children):
            return .scrollView(
                children:
                    children.map {
                        replacingMotionMarkers(
                            in: $0,
                            markers: markers
                        )
                    }
            )

        case .list(let children):
            return .list(
                children:
                    children.map {
                        replacingMotionMarkers(
                            in: $0,
                            markers: markers
                        )
                    }
            )

        case .navigationStack(
            let children
        ):
            return .navigationStack(
                children:
                    children.map {
                        replacingMotionMarkers(
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
                    replacingMotionMarkers(
                        in:
                            destination,
                        markers:
                            markers
                    )
            )

        case .modified(
            let baseNode,
            let modifiers
        ):
            return .modified(
                base:
                    replacingMotionMarkers(
                        in: baseNode,
                        markers: markers
                    ),
                modifiers:
                    modifiers.map {
                        replacingMotionMarker(
                            in: $0,
                            markers: markers
                        )
                    }
            )

        default:
            return node
        }
    }

    private func replacingMotionMarker(
        in modifier: PreviewModifier,
        markers:
            [String: PreviewMotionMarkerSpec]
    ) -> PreviewModifier {
        switch modifier {
        case .navigationTitle(let title):
            guard let marker =
                    markers[title] else {
                return modifier
            }

            switch marker {
            case .animation(
                let animation,
                let stateName
            ):
                return .animation(
                    animation,
                    value:
                        PreviewBindingReference(
                            stateName:
                                stateName
                        )
                )

            case .transition(
                let transition
            ):
                return .transition(
                    transition
                )
            }

        case .sheet(
            let reference,
            let content
        ):
            return .sheet(
                isPresented: reference,
                content:
                    replacingMotionMarkers(
                        in: content,
                        markers:
                            markers
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
                content:
                    replacingMotionMarkers(
                        in: content,
                        markers:
                            markers
                    )
            )

        case .fullScreenCover(
            let reference,
            let content
        ):
            return .fullScreenCover(
                isPresented: reference,
                content:
                    replacingMotionMarkers(
                        in: content,
                        markers:
                            markers
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
                content:
                    replacingMotionMarkers(
                        in: content,
                        markers:
                            markers
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
                    message:
                        error.localizedDescription,
                    filePath:
                        filePath
                )
            ]
        )
    }
}

enum PreviewMotionMarkerSpec:
    Equatable,
    Sendable {
    case animation(
        PreviewAnimationSpec,
        stateName: String
    )
    case transition(
        PreviewTransition
    )
}

struct PreviewMotionSourceRewrite:
    Equatable,
    Sendable {
    let source: String
    let markers:
        [String: PreviewMotionMarkerSpec]
}

enum PreviewMotionSourceError:
    Error,
    Equatable,
    Sendable {
    case malformedMotionModifier
    case unknownAnimationState(String)
}

extension PreviewMotionSourceError:
    LocalizedError {
    var errorDescription: String? {
        switch self {
        case .malformedMotionModifier:
            return
                "Preview motion modifier is malformed or uses an unsupported animation/transition form."

        case .unknownAnimationState(
            let stateName
        ):
            return
                "Preview animation references unknown @State '\(stateName)'."
        }
    }
}

struct PreviewMotionSourceRewriter {
    let source: String

    func rewrite() throws
        -> PreviewMotionSourceRewrite {
        let animationMatches =
            try animationReplacements()
        let transitionMatches =
            try transitionReplacements()

        let all =
            animationMatches +
            transitionMatches

        guard !all.isEmpty else {
            return PreviewMotionSourceRewrite(
                source: source,
                markers: [:]
            )
        }

        var markers:
            [String: PreviewMotionMarkerSpec] =
                [:]
        var replacements:
            [PreviewMotionReplacement] = []

        for item in all.sorted(
            by: {
                $0.range.location <
                    $1.range.location
            }
        ) {
            let marker =
                "__ISWIFT_MOTION_\(markers.count)__"

            markers[marker] =
                item.spec

            replacements.append(
                PreviewMotionReplacement(
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

        return PreviewMotionSourceRewrite(
            source:
                mutable as String,
            markers: markers
        )
    }

    private func animationReplacements()
        throws
        -> [PreviewMotionMatch] {
        var matches:
            [PreviewMotionMatch] = []

        let curvePattern =
            #"\.animation\s*\(\s*\.(default|linear|easeIn|easeOut|easeInOut)\s*(?:\(\s*duration\s*:\s*([0-9]+(?:\.[0-9]+)?)\s*\))?\s*,\s*value\s*:\s*([A-Za-z_][A-Za-z0-9_]*)\s*\)"#

        let curveRegex =
            try NSRegularExpression(
                pattern: curvePattern
            )

        let nsSource =
            source as NSString

        for match in curveRegex.matches(
            in: source,
            range: NSRange(
                location: 0,
                length:
                    nsSource.length
            )
        ) {
            guard match.numberOfRanges >= 4,
                  isCodeLocation(
                    match.range.location
                  ) else {
                continue
            }

            let curveRaw =
                nsSource.substring(
                    with:
                        match.range(at: 1)
                )
            let stateName =
                nsSource.substring(
                    with:
                        match.range(at: 3)
                )

            guard let curve =
                    PreviewAnimationCurve(
                        rawValue:
                            curveRaw
                    ) else {
                continue
            }

            var duration: Double?

            let durationRange =
                match.range(at: 2)

            if durationRange.location !=
                NSNotFound {
                duration = Double(
                    nsSource.substring(
                        with:
                            durationRange
                    )
                )
            }

            matches.append(
                PreviewMotionMatch(
                    range: match.range,
                    spec:
                        .animation(
                            PreviewAnimationSpec(
                                curve: curve,
                                duration:
                                    duration
                            ),
                            stateName:
                                stateName
                        )
                )
            )
        }

        let springPattern =
            #"\.animation\s*\(\s*\.spring\s*\(\s*\)\s*,\s*value\s*:\s*([A-Za-z_][A-Za-z0-9_]*)\s*\)"#

        let springRegex =
            try NSRegularExpression(
                pattern: springPattern
            )

        for match in springRegex.matches(
            in: source,
            range: NSRange(
                location: 0,
                length:
                    nsSource.length
            )
        ) {
            guard match.numberOfRanges >= 2,
                  isCodeLocation(
                    match.range.location
                  ) else {
                continue
            }

            matches.append(
                PreviewMotionMatch(
                    range: match.range,
                    spec:
                        .animation(
                            PreviewAnimationSpec(
                                curve: .spring
                            ),
                            stateName:
                                nsSource.substring(
                                    with:
                                        match.range(
                                            at: 1
                                        )
                                )
                        )
                )
            )
        }

        return deduplicated(
            matches
        )
    }

    private func transitionReplacements()
        throws
        -> [PreviewMotionMatch] {
        var matches:
            [PreviewMotionMatch] = []

        let simplePattern =
            #"\.transition\s*\(\s*\.(opacity|scale|slide)\s*\)"#

        let simpleRegex =
            try NSRegularExpression(
                pattern: simplePattern
            )

        let nsSource =
            source as NSString

        for match in simpleRegex.matches(
            in: source,
            range: NSRange(
                location: 0,
                length:
                    nsSource.length
            )
        ) {
            guard match.numberOfRanges >= 2,
                  isCodeLocation(
                    match.range.location
                  ) else {
                continue
            }

            let raw =
                nsSource.substring(
                    with:
                        match.range(at: 1)
                )

            let transition:
                PreviewTransition

            switch raw {
            case "opacity":
                transition = .opacity
            case "scale":
                transition = .scale
            case "slide":
                transition = .slide
            default:
                continue
            }

            matches.append(
                PreviewMotionMatch(
                    range: match.range,
                    spec:
                        .transition(
                            transition
                        )
                )
            )
        }

        let movePattern =
            #"\.transition\s*\(\s*\.move\s*\(\s*edge\s*:\s*\.(leading|trailing|top|bottom)\s*\)\s*\)"#

        let moveRegex =
            try NSRegularExpression(
                pattern: movePattern
            )

        for match in moveRegex.matches(
            in: source,
            range: NSRange(
                location: 0,
                length:
                    nsSource.length
            )
        ) {
            guard match.numberOfRanges >= 2,
                  isCodeLocation(
                    match.range.location
                  ) else {
                continue
            }

            let raw =
                nsSource.substring(
                    with:
                        match.range(at: 1)
                )

            guard let edge =
                    PreviewTransitionEdge(
                        rawValue: raw
                    ) else {
                continue
            }

            matches.append(
                PreviewMotionMatch(
                    range: match.range,
                    spec:
                        .transition(
                            .move(edge)
                        )
                )
            )
        }

        return deduplicated(
            matches
        )
    }

    private func deduplicated(
        _ matches:
            [PreviewMotionMatch]
    ) -> [PreviewMotionMatch] {
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
    ) -> PreviewMotionLexicalState {
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

private struct PreviewMotionMatch {
    let range: NSRange
    let spec: PreviewMotionMarkerSpec
}

private struct PreviewMotionReplacement {
    let range: NSRange
    let replacement: String
}

private enum PreviewMotionLexicalState {
    case code
    case string
    case lineComment
}
