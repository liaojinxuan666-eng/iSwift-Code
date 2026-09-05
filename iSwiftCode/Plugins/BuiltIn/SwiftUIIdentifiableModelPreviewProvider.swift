import Foundation

/// Adds constrained source-model support above the existing presentation stack.
///
/// The provider recognizes a deliberately small, portable subset:
///
/// ```swift
/// struct DetailItem: Identifiable {
///     let id: Int
///     let title: String
/// }
///
/// @State private var selectedItem: DetailItem? = nil
/// ```
///
/// User model code is never executed. The source declaration is validated,
/// custom optional state is temporarily rewritten to a primitive placeholder
/// for the existing parser stack, then the resulting state definition is
/// restored as portable Identifiable-item IR.
final class SwiftUIIdentifiableModelPreviewProvider: PreviewProvider {
    private let base =
        SwiftUIFullScreenCoverItemPreviewProvider()

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
        guard let selectedIndex = selectedFileIndex(
            in: request
        ) else {
            return try base.makePreview(request)
        }

        let selectedFile =
            request.files[selectedIndex]

        let scan: PreviewIdentifiableModelSourceScan

        do {
            scan = try PreviewIdentifiableModelSourceScanner(
                source: selectedFile.contents
            ).scan()
        } catch {
            return diagnosticResult(
                error,
                filePath: selectedFile.path
            )
        }

        guard !scan.states.isEmpty else {
            return try base.makePreview(request)
        }

        var rewrittenFiles = request.files
        rewrittenFiles[selectedIndex] =
            PreviewSourceFile(
                path: selectedFile.path,
                contents: scan.rewrittenSource
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

        var definitions =
            document.stateDefinitions

        for state in scan.states {
            guard let index =
                    definitions.firstIndex(
                        where: {
                            $0.name ==
                                state.stateName
                        }
                    ) else {
                return diagnosticResult(
                    PreviewIdentifiableModelSourceError
                        .stateNotLowered(
                            state.stateName
                        ),
                    filePath:
                        selectedFile.path
                )
            }

            definitions[index] =
                PreviewStateDefinition(
                    name: state.stateName,
                    initialValue:
                        .optionalIdentifiableItem(
                            PreviewOptionalIdentifiableItemState(
                                itemTypeName:
                                    state.modelTypeName
                            )
                        )
                )
        }

        return PreviewProviderResult(
            document: PreviewDocument(
                root: document.root,
                stateDefinitions: definitions,
                sourceFilePath:
                    document.sourceFilePath,
                title: document.title
            ),
            diagnostics:
                baseResult.diagnostics
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

private struct PreviewIdentifiableModelSchema {
    let typeName: String
    let memberTypes: [String: String]
}

private struct PreviewIdentifiableModelState {
    let stateName: String
    let modelTypeName: String
}

private struct PreviewIdentifiableModelSourceScan {
    let rewrittenSource: String
    let states: [PreviewIdentifiableModelState]
}

private enum PreviewIdentifiableModelSourceError:
    Error {
    case malformedModel(String)
    case missingID(String)
    case unsupportedMember(
        model: String,
        member: String,
        type: String
    )
    case stateNotLowered(String)
}

extension PreviewIdentifiableModelSourceError:
    LocalizedError {
    var errorDescription: String? {
        switch self {
        case .malformedModel(let name):
            return
                "Identifiable preview model '\(name)' has an unterminated declaration."

        case .missingID(let name):
            return
                "Identifiable preview model '\(name)' must declare a stored 'id' member."

        case .unsupportedMember(
            let model,
            let member,
            let type
        ):
            return
                "Identifiable preview model '\(model)' member '\(member)' uses unsupported type '\(type)'. Use String, Bool, Int, Double, or Float."

        case .stateNotLowered(let name):
            return
                "Identifiable preview @State '\(name)' could not be lowered by the base preview parser."
        }
    }
}

private struct PreviewIdentifiableModelSourceScanner {
    let source: String

    func scan() throws
        -> PreviewIdentifiableModelSourceScan {
        let schemas = try scanSchemas()

        guard !schemas.isEmpty else {
            return PreviewIdentifiableModelSourceScan(
                rewrittenSource: source,
                states: []
            )
        }

        let statePattern =
            #"@State\s+(?:(?:private|fileprivate|internal|public)\s+)?var\s+([A-Za-z_][A-Za-z0-9_]*)\s*:\s*([A-Za-z_][A-Za-z0-9_]*)\s*\?\s*=\s*nil"#

        let regex = try NSRegularExpression(
            pattern: statePattern
        )
        let nsSource = source as NSString
        let matches = regex.matches(
            in: source,
            range: NSRange(
                location: 0,
                length: nsSource.length
            )
        )

        var states:
            [PreviewIdentifiableModelState] = []
        var replacements:
            [(range: NSRange, text: String)] = []

        for match in matches {
            guard match.numberOfRanges >= 3 else {
                continue
            }

            let stateName =
                nsSource.substring(
                    with: match.range(at: 1)
                )
            let typeName =
                nsSource.substring(
                    with: match.range(at: 2)
                )

            guard schemas[typeName] != nil else {
                continue
            }

            states.append(
                PreviewIdentifiableModelState(
                    stateName: stateName,
                    modelTypeName: typeName
                )
            )

            // The existing state scanner already understands String?.
            // Rewriting only the type token lets every established provider
            // continue parsing presentation syntax unchanged.
            replacements.append(
                (
                    range: match.range(at: 2),
                    text: "String"
                )
            )
        }

        guard !states.isEmpty else {
            return PreviewIdentifiableModelSourceScan(
                rewrittenSource: source,
                states: []
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
                with: replacement.text
            )
        }

        return PreviewIdentifiableModelSourceScan(
            rewrittenSource:
                mutable as String,
            states: states
        )
    }

    private func scanSchemas() throws
        -> [String: PreviewIdentifiableModelSchema] {
        let declarationPattern =
            #"\bstruct\s+([A-Za-z_][A-Za-z0-9_]*)\s*:\s*([^{]+)\{"#

        let regex = try NSRegularExpression(
            pattern: declarationPattern
        )
        let nsSource = source as NSString
        let matches = regex.matches(
            in: source,
            range: NSRange(
                location: 0,
                length: nsSource.length
            )
        )

        var schemas:
            [String: PreviewIdentifiableModelSchema] = [:]

        for match in matches {
            guard match.numberOfRanges >= 3 else {
                continue
            }

            let typeName =
                nsSource.substring(
                    with: match.range(at: 1)
                )
            let inheritance =
                nsSource.substring(
                    with: match.range(at: 2)
                )

            let inheritedNames =
                inheritance
                    .split(separator: ",")
                    .map {
                        $0.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        )
                    }

            guard inheritedNames.contains(
                "Identifiable"
            ) else {
                continue
            }

            let openingBraceLocation =
                NSMaxRange(match.range) - 1

            guard let closingBraceLocation =
                    matchingBraceLocation(
                        openingBraceLocation:
                            openingBraceLocation
                    ) else {
                throw
                    PreviewIdentifiableModelSourceError
                        .malformedModel(typeName)
            }

            let bodyStart =
                openingBraceLocation + 1
            let bodyRange = NSRange(
                location: bodyStart,
                length:
                    closingBraceLocation -
                    bodyStart
            )
            let body =
                nsSource.substring(
                    with: bodyRange
                )

            let memberTypes =
                try scanMemberTypes(
                    modelName: typeName,
                    body: body
                )

            guard memberTypes["id"] != nil else {
                throw
                    PreviewIdentifiableModelSourceError
                        .missingID(typeName)
            }

            schemas[typeName] =
                PreviewIdentifiableModelSchema(
                    typeName: typeName,
                    memberTypes: memberTypes
                )
        }

        return schemas
    }

    private func scanMemberTypes(
        modelName: String,
        body: String
    ) throws -> [String: String] {
        let memberPattern =
            #"\b(?:let|var)\s+([A-Za-z_][A-Za-z0-9_]*)\s*:\s*([A-Za-z_][A-Za-z0-9_]*)"#

        let regex = try NSRegularExpression(
            pattern: memberPattern
        )
        let nsBody = body as NSString
        let matches = regex.matches(
            in: body,
            range: NSRange(
                location: 0,
                length: nsBody.length
            )
        )

        let allowedTypes: Set<String> = [
            "String",
            "Bool",
            "Int",
            "Double",
            "Float"
        ]

        var memberTypes:
            [String: String] = [:]

        for match in matches {
            guard match.numberOfRanges >= 3 else {
                continue
            }

            let memberName =
                nsBody.substring(
                    with: match.range(at: 1)
                )
            let typeName =
                nsBody.substring(
                    with: match.range(at: 2)
                )

            guard allowedTypes.contains(
                typeName
            ) else {
                throw
                    PreviewIdentifiableModelSourceError
                        .unsupportedMember(
                            model: modelName,
                            member: memberName,
                            type: typeName
                        )
            }

            memberTypes[memberName] =
                typeName
        }

        return memberTypes
    }

    private func matchingBraceLocation(
        openingBraceLocation: Int
    ) -> Int? {
        let nsSource = source as NSString

        var index = openingBraceLocation
        var depth = 0
        var inString = false
        var escaped = false
        var inLineComment = false

        while index < nsSource.length {
            let scalar =
                nsSource.character(at: index)

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
               index + 1 < nsSource.length,
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
}
