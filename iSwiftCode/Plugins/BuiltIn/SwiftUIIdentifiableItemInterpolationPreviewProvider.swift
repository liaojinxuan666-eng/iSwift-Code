import Foundation

/// Adds string interpolation for portable Identifiable item members.
///
/// Supported first-step syntax:
///
/// ```swift
/// .sheet(item: $selectedItem) { item in
///     Text("Title: \(item.title)")
///     Text("ID: \(item.id)")
/// }
/// ```
///
/// The same form is supported inside `.fullScreenCover(item:)`.
/// Multiple item members and ordinary preview-state interpolation may coexist
/// in the same Text literal. User property getters are never executed.
final class SwiftUIIdentifiableItemInterpolationPreviewProvider:
    PreviewProvider {
    private let base =
        SwiftUIIdentifiableItemMemberPreviewProvider()

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

        let selectedFile =
            request.files[selectedIndex]

        let rewrite:
            PreviewIdentifiableItemInterpolationRewrite

        do {
            rewrite =
                try PreviewIdentifiableItemInterpolationSourceRewriter(
                    source: selectedFile.contents
                ).rewrite()
        } catch {
            return diagnosticResult(
                error,
                filePath: selectedFile.path
            )
        }

        guard !rewrite.membersByMarker.isEmpty else {
            return try base.makePreview(request)
        }

        var rewrittenFiles = request.files
        rewrittenFiles[selectedIndex] =
            PreviewSourceFile(
                path: selectedFile.path,
                contents: rewrite.source
            )

        let baseResult = try base.makePreview(
            PreviewRequest(
                files: rewrittenFiles,
                entryFilePath:
                    request.entryFilePath,
                platform: request.platform,
                deviceFamily:
                    request.deviceFamily
            )
        )

        guard let document =
                baseResult.document,
              baseResult.succeeded else {
            return baseResult
        }

        do {
            try validateMemberBindings(
                rewrite.membersByMarker,
                definitions:
                    document.stateDefinitions
            )

            return PreviewProviderResult(
                document: PreviewDocument(
                    root:
                        replacingInterpolationMarkers(
                            in: document.root,
                            membersByMarker:
                                rewrite.membersByMarker
                        ),
                    stateDefinitions:
                        document.stateDefinitions,
                    sourceFilePath:
                        document.sourceFilePath,
                    title: document.title
                ),
                diagnostics:
                    baseResult.diagnostics
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

    private func validateMemberBindings(
        _ membersByMarker:
            [String:
                PreviewIdentifiableItemInterpolationSpec],
        definitions: [PreviewStateDefinition]
    ) throws {
        for spec in membersByMarker.values {
            guard let definition =
                    definitions.first(
                        where: {
                            $0.name ==
                                spec.stateName
                        }
                    ) else {
                throw
                    PreviewIdentifiableItemInterpolationError
                        .unknownState(
                            spec.stateName
                        )
            }

            guard case .optionalIdentifiableItem =
                    definition.initialValue else {
                throw
                    PreviewIdentifiableItemInterpolationError
                        .requiresIdentifiableState(
                            spec.stateName
                        )
            }
        }
    }

    private func replacingInterpolationMarkers(
        in node: PreviewNode,
        membersByMarker:
            [String:
                PreviewIdentifiableItemInterpolationSpec]
    ) -> PreviewNode {
        switch node {
        case .text(let value):
            return replacingTextNode(
                template: value,
                membersByMarker:
                    membersByMarker,
                fallback: node
            )

        case .interpolatedText(let value):
            return replacingTextNode(
                template: value,
                membersByMarker:
                    membersByMarker,
                fallback: node
            )

        case .vStack(let children):
            return .vStack(
                children: children.map {
                    replacingInterpolationMarkers(
                        in: $0,
                        membersByMarker:
                            membersByMarker
                    )
                }
            )

        case .hStack(let children):
            return .hStack(
                children: children.map {
                    replacingInterpolationMarkers(
                        in: $0,
                        membersByMarker:
                            membersByMarker
                    )
                }
            )

        case .zStack(let children):
            return .zStack(
                children: children.map {
                    replacingInterpolationMarkers(
                        in: $0,
                        membersByMarker:
                            membersByMarker
                    )
                }
            )

        case .scrollView(let children):
            return .scrollView(
                children: children.map {
                    replacingInterpolationMarkers(
                        in: $0,
                        membersByMarker:
                            membersByMarker
                    )
                }
            )

        case .list(let children):
            return .list(
                children: children.map {
                    replacingInterpolationMarkers(
                        in: $0,
                        membersByMarker:
                            membersByMarker
                    )
                }
            )

        case .navigationStack(let children):
            return .navigationStack(
                children: children.map {
                    replacingInterpolationMarkers(
                        in: $0,
                        membersByMarker:
                            membersByMarker
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
                    replacingInterpolationMarkers(
                        in: destination,
                        membersByMarker:
                            membersByMarker
                    )
            )

        case .modified(
            let baseNode,
            let modifiers
        ):
            return .modified(
                base:
                    replacingInterpolationMarkers(
                        in: baseNode,
                        membersByMarker:
                            membersByMarker
                    ),
                modifiers: modifiers.map {
                    replacingInterpolationMarkers(
                        in: $0,
                        membersByMarker:
                            membersByMarker
                    )
                }
            )

        default:
            return node
        }
    }

    private func replacingTextNode(
        template: String,
        membersByMarker:
            [String:
                PreviewIdentifiableItemInterpolationSpec],
        fallback: PreviewNode
    ) -> PreviewNode {
        let matchingMarkers =
            membersByMarker.keys
                .filter {
                    template.contains($0)
                }
                .sorted()

        guard !matchingMarkers.isEmpty else {
            return fallback
        }

        let members =
            matchingMarkers.compactMap { marker
                -> PreviewItemMemberInterpolation? in
                guard let spec =
                        membersByMarker[marker]
                else {
                    return nil
                }

                return PreviewItemMemberInterpolation(
                    marker: marker,
                    stateName: spec.stateName,
                    memberName: spec.memberName
                )
            }

        return .itemMemberInterpolatedText(
            template: template,
            members: members
        )
    }

    private func replacingInterpolationMarkers(
        in modifier: PreviewModifier,
        membersByMarker:
            [String:
                PreviewIdentifiableItemInterpolationSpec]
    ) -> PreviewModifier {
        switch modifier {
        case .sheet(
            let reference,
            let content
        ):
            return .sheet(
                isPresented: reference,
                content:
                    replacingInterpolationMarkers(
                        in: content,
                        membersByMarker:
                            membersByMarker
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
                    replacingInterpolationMarkers(
                        in: content,
                        membersByMarker:
                            membersByMarker
                    )
            )

        case .fullScreenCover(
            let reference,
            let content
        ):
            return .fullScreenCover(
                isPresented: reference,
                content:
                    replacingInterpolationMarkers(
                        in: content,
                        membersByMarker:
                            membersByMarker
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
                    replacingInterpolationMarkers(
                        in: content,
                        membersByMarker:
                            membersByMarker
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
                    filePath: filePath
                )
            ]
        )
    }
}

private struct PreviewIdentifiableItemInterpolationSpec {
    let stateName: String
    let memberName: String
}

private struct PreviewIdentifiableItemInterpolationRewrite {
    let source: String
    let membersByMarker:
        [String:
            PreviewIdentifiableItemInterpolationSpec]
}

private enum PreviewIdentifiableItemInterpolationError:
    Error {
    case malformedPresentation
    case unknownState(String)
    case requiresIdentifiableState(String)
}

extension PreviewIdentifiableItemInterpolationError:
    LocalizedError {
    var errorDescription: String? {
        switch self {
        case .malformedPresentation:
            return
                "Identifiable item interpolation preview has a malformed item presentation closure."

        case .unknownState(let stateName):
            return
                "Identifiable item interpolation references unknown @State '\(stateName)'."

        case .requiresIdentifiableState(
            let stateName
        ):
            return
                "item.member interpolation requires custom Identifiable optional @State '\(stateName)'."
        }
    }
}

private struct PreviewIdentifiableInterpolationPresentation {
    let stateName: String
    let itemName: String
    let contentRange: NSRange
}

private struct PreviewIdentifiableItemInterpolationSourceRewriter {
    let source: String

    func rewrite() throws
        -> PreviewIdentifiableItemInterpolationRewrite {
        let presentations =
            try scanPresentations()

        guard !presentations.isEmpty else {
            return
                PreviewIdentifiableItemInterpolationRewrite(
                    source: source,
                    membersByMarker: [:]
                )
        }

        let nsSource = source as NSString

        var replacements:
            [(range: NSRange, marker: String)] = []
        var membersByMarker:
            [String:
                PreviewIdentifiableItemInterpolationSpec] = [:]
        var seenRanges = Set<String>()

        for presentation in presentations {
            let content =
                nsSource.substring(
                    with:
                        presentation.contentRange
                )

            let escapedItem =
                NSRegularExpression
                    .escapedPattern(
                        for:
                            presentation.itemName
                    )

            let pattern =
                #"\\\(\s*"# +
                escapedItem +
                #"\s*\.\s*([A-Za-z_][A-Za-z0-9_]*)\s*\)"#

            let regex =
                try NSRegularExpression(
                    pattern: pattern
                )

            let nsContent =
                content as NSString

            let matches = regex.matches(
                in: content,
                range: NSRange(
                    location: 0,
                    length:
                        nsContent.length
                )
            )

            for match in matches {
                guard match.numberOfRanges >= 2 else {
                    continue
                }

                let absoluteRange = NSRange(
                    location:
                        presentation
                            .contentRange
                            .location +
                        match.range.location,
                    length:
                        match.range.length
                )

                guard isInnermostMatch(
                    absoluteRange,
                    presentation:
                        presentation,
                    allPresentations:
                        presentations
                ) else {
                    continue
                }

                guard isStringLocation(
                    absoluteRange.location
                ) else {
                    continue
                }

                let key =
                    "\(absoluteRange.location):\(absoluteRange.length)"

                guard !seenRanges.contains(key) else {
                    continue
                }

                seenRanges.insert(key)

                let memberName =
                    nsContent.substring(
                        with:
                            match.range(at: 1)
                    )

                let marker =
                    "__ISWIFT_ITEM_MEMBER_INTERP_\(membersByMarker.count)__"

                membersByMarker[marker] =
                    PreviewIdentifiableItemInterpolationSpec(
                        stateName:
                            presentation.stateName,
                        memberName:
                            memberName
                    )

                replacements.append(
                    (
                        range: absoluteRange,
                        marker: marker
                    )
                )
            }
        }

        guard !replacements.isEmpty else {
            return
                PreviewIdentifiableItemInterpolationRewrite(
                    source: source,
                    membersByMarker: [:]
                )
        }

        let mutable =
            NSMutableString(string: source)

        for replacement in replacements
            .sorted(
                by: {
                    $0.range.location >
                        $1.range.location
                }
            ) {
            mutable.replaceCharacters(
                in: replacement.range,
                with: replacement.marker
            )
        }

        return PreviewIdentifiableItemInterpolationRewrite(
            source: mutable as String,
            membersByMarker:
                membersByMarker
        )
    }

    private func scanPresentations() throws
        -> [PreviewIdentifiableInterpolationPresentation] {
        let pattern =
            #"\.(?:sheet|fullScreenCover)\s*\(\s*item\s*:\s*\$([A-Za-z_][A-Za-z0-9_]*)\s*\)\s*\{\s*([A-Za-z_][A-Za-z0-9_]*)\s+in"#

        let regex =
            try NSRegularExpression(
                pattern: pattern
            )

        let nsSource = source as NSString
        let matches = regex.matches(
            in: source,
            range: NSRange(
                location: 0,
                length:
                    nsSource.length
            )
        )

        var presentations:
            [PreviewIdentifiableInterpolationPresentation] = []

        for match in matches {
            guard match.numberOfRanges >= 3,
                  isCodeLocation(
                    match.range.location
                  ) else {
                continue
            }

            let stateName =
                nsSource.substring(
                    with:
                        match.range(at: 1)
                )
            let itemName =
                nsSource.substring(
                    with:
                        match.range(at: 2)
                )

            let header =
                nsSource.substring(
                    with: match.range
                ) as NSString

            let braceInHeader =
                header.range(
                    of: "{",
                    options: .backwards
                )

            guard braceInHeader.location !=
                    NSNotFound else {
                throw
                    PreviewIdentifiableItemInterpolationError
                        .malformedPresentation
            }

            let openingBrace =
                match.range.location +
                braceInHeader.location

            guard let closingBrace =
                    matchingBraceLocation(
                        openingBrace
                    ) else {
                throw
                    PreviewIdentifiableItemInterpolationError
                        .malformedPresentation
            }

            let contentStart =
                NSMaxRange(match.range)

            guard closingBrace >= contentStart else {
                throw
                    PreviewIdentifiableItemInterpolationError
                        .malformedPresentation
            }

            presentations.append(
                PreviewIdentifiableInterpolationPresentation(
                    stateName: stateName,
                    itemName: itemName,
                    contentRange: NSRange(
                        location: contentStart,
                        length:
                            closingBrace -
                            contentStart
                    )
                )
            )
        }

        return presentations
    }

    private func isInnermostMatch(
        _ absoluteRange: NSRange,
        presentation:
            PreviewIdentifiableInterpolationPresentation,
        allPresentations:
            [PreviewIdentifiableInterpolationPresentation]
    ) -> Bool {
        for other in allPresentations {
            guard other.contentRange.location !=
                    presentation.contentRange.location ||
                  other.contentRange.length !=
                    presentation.contentRange.length
            else {
                continue
            }

            let start =
                absoluteRange.location
            let end =
                NSMaxRange(absoluteRange)
            let otherStart =
                other.contentRange.location
            let otherEnd =
                NSMaxRange(
                    other.contentRange
                )

            if start >= otherStart,
               end <= otherEnd,
               other.contentRange.length <
                    presentation.contentRange.length {
                return false
            }
        }

        return true
    }

    private func matchingBraceLocation(
        _ openingBrace: Int
    ) -> Int? {
        let nsSource = source as NSString

        var index = openingBrace
        var depth = 0
        var inString = false
        var escaped = false
        var inLineComment = false

        while index < nsSource.length {
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

            if scalar == 123 {
                depth += 1
            } else if scalar == 125 {
                depth -= 1

                if depth == 0 {
                    return index
                }
            }

            index += 1
        }

        return nil
    }

    private func isCodeLocation(
        _ location: Int
    ) -> Bool {
        lexicalState(
            at: location
        ) == .code
    }

    private func isStringLocation(
        _ location: Int
    ) -> Bool {
        lexicalState(
            at: location
        ) == .string
    }

    private func lexicalState(
        at location: Int
    ) -> PreviewInterpolationLexicalState {
        let nsSource = source as NSString

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

private enum PreviewInterpolationLexicalState {
    case code
    case string
    case lineComment
}
