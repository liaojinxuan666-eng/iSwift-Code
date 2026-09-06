import Foundation

/// Adds direct member access for portable Identifiable item presentation.
///
/// Supported first-step syntax:
///
/// ```swift
/// .sheet(item: $selectedItem) { item in
///     Text(item.title)
///     Text(item.id)
/// }
/// ```
///
/// and the same content form inside `.fullScreenCover(item:)`.
///
/// The source member expression is never executed. It is replaced with a
/// temporary literal marker before the established provider stack parses the
/// document. The marker is then restored as `PreviewNode.itemMemberText`.
final class SwiftUIIdentifiableItemMemberPreviewProvider:
    PreviewProvider {
    private let base =
        SwiftUIIdentifiableModelActionPreviewProvider()

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

        let rewrite =
            try PreviewIdentifiableItemMemberSourceRewriter(
                source: selectedFile.contents
            ).rewrite()

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

        guard let document = baseResult.document,
              baseResult.succeeded else {
            return baseResult
        }

        do {
            try validateMemberBindings(
                rewrite.membersByMarker,
                definitions:
                    document.stateDefinitions
            )

            let root = replacingMemberMarkers(
                in: document.root,
                membersByMarker:
                    rewrite.membersByMarker
            )

            return PreviewProviderResult(
                document: PreviewDocument(
                    root: root,
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
            [String: PreviewIdentifiableItemMemberSpec],
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
                    PreviewIdentifiableItemMemberError
                        .unknownState(
                            spec.stateName
                        )
            }

            guard case .optionalIdentifiableItem =
                    definition.initialValue else {
                throw
                    PreviewIdentifiableItemMemberError
                        .requiresIdentifiableState(
                            spec.stateName
                        )
            }
        }
    }

    private func replacingMemberMarkers(
        in node: PreviewNode,
        membersByMarker:
            [String: PreviewIdentifiableItemMemberSpec]
    ) -> PreviewNode {
        switch node {
        case .text(let value):
            guard let spec =
                    membersByMarker[value] else {
                return node
            }

            return .itemMemberText(
                stateName: spec.stateName,
                memberName: spec.memberName
            )

        case .vStack(let children):
            return .vStack(
                children: children.map {
                    replacingMemberMarkers(
                        in: $0,
                        membersByMarker:
                            membersByMarker
                    )
                }
            )

        case .hStack(let children):
            return .hStack(
                children: children.map {
                    replacingMemberMarkers(
                        in: $0,
                        membersByMarker:
                            membersByMarker
                    )
                }
            )

        case .zStack(let children):
            return .zStack(
                children: children.map {
                    replacingMemberMarkers(
                        in: $0,
                        membersByMarker:
                            membersByMarker
                    )
                }
            )

        case .scrollView(let children):
            return .scrollView(
                children: children.map {
                    replacingMemberMarkers(
                        in: $0,
                        membersByMarker:
                            membersByMarker
                    )
                }
            )

        case .list(let children):
            return .list(
                children: children.map {
                    replacingMemberMarkers(
                        in: $0,
                        membersByMarker:
                            membersByMarker
                    )
                }
            )

        case .navigationStack(let children):
            return .navigationStack(
                children: children.map {
                    replacingMemberMarkers(
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
                    replacingMemberMarkers(
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
                base: replacingMemberMarkers(
                    in: baseNode,
                    membersByMarker:
                        membersByMarker
                ),
                modifiers: modifiers.map {
                    replacingMemberMarkers(
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

    private func replacingMemberMarkers(
        in modifier: PreviewModifier,
        membersByMarker:
            [String: PreviewIdentifiableItemMemberSpec]
    ) -> PreviewModifier {
        switch modifier {
        case .sheet(
            let reference,
            let content
        ):
            return .sheet(
                isPresented: reference,
                content: replacingMemberMarkers(
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
                content: replacingMemberMarkers(
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
                content: replacingMemberMarkers(
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
                content: replacingMemberMarkers(
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

private struct PreviewIdentifiableItemMemberSpec {
    let stateName: String
    let memberName: String
}

private struct PreviewIdentifiableItemMemberRewrite {
    let source: String
    let membersByMarker:
        [String: PreviewIdentifiableItemMemberSpec]
}

private enum PreviewIdentifiableItemMemberError:
    Error {
    case malformedPresentation
    case unknownState(String)
    case requiresIdentifiableState(String)
}

extension PreviewIdentifiableItemMemberError:
    LocalizedError {
    var errorDescription: String? {
        switch self {
        case .malformedPresentation:
            return
                "Identifiable item member preview has a malformed item presentation closure."

        case .unknownState(let stateName):
            return
                "Identifiable item member preview references unknown @State '\(stateName)'."

        case .requiresIdentifiableState(
            let stateName
        ):
            return
                "Direct item.member preview requires custom Identifiable optional @State '\(stateName)'."
        }
    }
}

private struct PreviewIdentifiableItemPresentation {
    let stateName: String
    let itemName: String
    let contentRange: NSRange
}

private struct PreviewIdentifiableItemMemberSourceRewriter {
    let source: String

    func rewrite() throws
        -> PreviewIdentifiableItemMemberRewrite {
        let presentations =
            try scanPresentations()

        guard !presentations.isEmpty else {
            return
                PreviewIdentifiableItemMemberRewrite(
                    source: source,
                    membersByMarker: [:]
                )
        }

        let nsSource = source as NSString
        var replacements:
            [(range: NSRange, marker: String)] = []
        var membersByMarker:
            [String: PreviewIdentifiableItemMemberSpec] = [:]
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
                #"Text\s*\(\s*"# +
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

                guard isCodeLocation(
                    absoluteRange.location
                ) else {
                    continue
                }

                let key =
                    "\(absoluteRange.location):\(absoluteRange.length)"

                guard !seenRanges.contains(key)
                else {
                    continue
                }

                seenRanges.insert(key)

                let memberName =
                    nsContent.substring(
                        with:
                            match.range(at: 1)
                    )

                let marker =
                    "__ISWIFT_ITEM_MEMBER_TEXT_\(membersByMarker.count)__"

                membersByMarker[marker] =
                    PreviewIdentifiableItemMemberSpec(
                        stateName:
                            presentation.stateName,
                        memberName:
                            memberName
                    )

                replacements.append(
                    (
                        range: absoluteRange,
                        marker:
                            "Text(\"\(marker)\")"
                    )
                )
            }
        }

        guard !replacements.isEmpty else {
            return
                PreviewIdentifiableItemMemberRewrite(
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

        return PreviewIdentifiableItemMemberRewrite(
            source: mutable as String,
            membersByMarker:
                membersByMarker
        )
    }

    private func scanPresentations() throws
        -> [PreviewIdentifiableItemPresentation] {
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
            [PreviewIdentifiableItemPresentation] = []

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
                    PreviewIdentifiableItemMemberError
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
                    PreviewIdentifiableItemMemberError
                        .malformedPresentation
            }

            let contentStart =
                NSMaxRange(match.range)

            guard closingBrace >= contentStart else {
                throw
                    PreviewIdentifiableItemMemberError
                        .malformedPresentation
            }

            presentations.append(
                PreviewIdentifiableItemPresentation(
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
            PreviewIdentifiableItemPresentation,
        allPresentations:
            [PreviewIdentifiableItemPresentation]
    ) -> Bool {
        for other in allPresentations {
            guard other.contentRange.location !=
                    presentation.contentRange.location ||
                  other.contentRange.length !=
                    presentation.contentRange.length
            else {
                continue
            }

            let matchStart =
                absoluteRange.location
            let matchEnd =
                NSMaxRange(absoluteRange)

            let otherStart =
                other.contentRange.location
            let otherEnd =
                NSMaxRange(
                    other.contentRange
                )

            if matchStart >= otherStart,
               matchEnd <= otherEnd,
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

        return !inString &&
            !inLineComment
    }
}
