import Foundation

/// Adds constrained Identifiable model-constructor action lowering above the
/// source-model preview provider.
///
/// Supported assignments remain portable and never execute user source code:
///
/// ```swift
/// selectedItem = DetailItem(
///     id: 1,
///     title: "Details"
/// )
/// ```
///
/// The constructor is converted to `PreviewIdentifiableItem`, while the source
/// assignment is temporarily replaced by a primitive marker that the existing
/// Button/onDismiss action stack already knows how to validate. After the base
/// provider finishes, marker values are restored to Identifiable-item IR and
/// validated against the final custom item state definition.
final class SwiftUIIdentifiableModelActionPreviewProvider: PreviewProvider {
    private let base =
        SwiftUIIdentifiableModelPreviewProvider()

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

        let selectedFile = request.files[selectedIndex]
        let rewrite: PreviewIdentifiableConstructorRewrite

        do {
            rewrite = try PreviewIdentifiableConstructorSourceRewriter(
                source: selectedFile.contents
            ).rewrite()
        } catch {
            return diagnosticResult(
                error,
                filePath: selectedFile.path
            )
        }

        guard !rewrite.itemsByMarker.isEmpty else {
            return try base.makePreview(request)
        }

        var rewrittenFiles = request.files
        rewrittenFiles[selectedIndex] = PreviewSourceFile(
            path: selectedFile.path,
            contents: rewrite.source
        )

        let baseResult = try base.makePreview(
            PreviewRequest(
                files: rewrittenFiles,
                entryFilePath: request.entryFilePath,
                platform: request.platform,
                deviceFamily: request.deviceFamily
            )
        )

        guard let document = baseResult.document,
              baseResult.succeeded else {
            return baseResult
        }

        do {
            let root = try replacingConstructorMarkers(
                in: document.root,
                itemsByMarker: rewrite.itemsByMarker,
                definitions: document.stateDefinitions
            )

            return PreviewProviderResult(
                document: PreviewDocument(
                    root: root,
                    stateDefinitions: document.stateDefinitions,
                    sourceFilePath: document.sourceFilePath,
                    title: document.title
                ),
                diagnostics: baseResult.diagnostics
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

    private func replacingConstructorMarkers(
        in node: PreviewNode,
        itemsByMarker: [String: PreviewIdentifiableItem],
        definitions: [PreviewStateDefinition]
    ) throws -> PreviewNode {
        switch node {
        case .actionButton(
            let title,
            let program
        ):
            return .actionButton(
                title: title,
                program: try replacingConstructorMarkers(
                    in: program,
                    itemsByMarker: itemsByMarker,
                    definitions: definitions
                )
            )

        case .vStack(let children):
            return .vStack(
                children: try children.map {
                    try replacingConstructorMarkers(
                        in: $0,
                        itemsByMarker: itemsByMarker,
                        definitions: definitions
                    )
                }
            )

        case .hStack(let children):
            return .hStack(
                children: try children.map {
                    try replacingConstructorMarkers(
                        in: $0,
                        itemsByMarker: itemsByMarker,
                        definitions: definitions
                    )
                }
            )

        case .zStack(let children):
            return .zStack(
                children: try children.map {
                    try replacingConstructorMarkers(
                        in: $0,
                        itemsByMarker: itemsByMarker,
                        definitions: definitions
                    )
                }
            )

        case .scrollView(let children):
            return .scrollView(
                children: try children.map {
                    try replacingConstructorMarkers(
                        in: $0,
                        itemsByMarker: itemsByMarker,
                        definitions: definitions
                    )
                }
            )

        case .list(let children):
            return .list(
                children: try children.map {
                    try replacingConstructorMarkers(
                        in: $0,
                        itemsByMarker: itemsByMarker,
                        definitions: definitions
                    )
                }
            )

        case .navigationStack(let children):
            return .navigationStack(
                children: try children.map {
                    try replacingConstructorMarkers(
                        in: $0,
                        itemsByMarker: itemsByMarker,
                        definitions: definitions
                    )
                }
            )

        case .navigationLink(
            let title,
            let destination
        ):
            return .navigationLink(
                title: title,
                destination: try replacingConstructorMarkers(
                    in: destination,
                    itemsByMarker: itemsByMarker,
                    definitions: definitions
                )
            )

        case .modified(
            let baseNode,
            let modifiers
        ):
            return .modified(
                base: try replacingConstructorMarkers(
                    in: baseNode,
                    itemsByMarker: itemsByMarker,
                    definitions: definitions
                ),
                modifiers: try modifiers.map {
                    try replacingConstructorMarkers(
                        in: $0,
                        itemsByMarker: itemsByMarker,
                        definitions: definitions
                    )
                }
            )

        default:
            return node
        }
    }

    private func replacingConstructorMarkers(
        in modifier: PreviewModifier,
        itemsByMarker: [String: PreviewIdentifiableItem],
        definitions: [PreviewStateDefinition]
    ) throws -> PreviewModifier {
        switch modifier {
        case .sheet(
            let reference,
            let content
        ):
            return .sheet(
                isPresented: reference,
                content: try replacingConstructorMarkers(
                    in: content,
                    itemsByMarker: itemsByMarker,
                    definitions: definitions
                )
            )

        case .sheetWithOnDismiss(
            let reference,
            let program,
            let content
        ):
            return .sheetWithOnDismiss(
                isPresented: reference,
                onDismiss: try replacingConstructorMarkers(
                    in: program,
                    itemsByMarker: itemsByMarker,
                    definitions: definitions
                ),
                content: try replacingConstructorMarkers(
                    in: content,
                    itemsByMarker: itemsByMarker,
                    definitions: definitions
                )
            )

        case .fullScreenCover(
            let reference,
            let content
        ):
            return .fullScreenCover(
                isPresented: reference,
                content: try replacingConstructorMarkers(
                    in: content,
                    itemsByMarker: itemsByMarker,
                    definitions: definitions
                )
            )

        case .fullScreenCoverWithOnDismiss(
            let reference,
            let program,
            let content
        ):
            return .fullScreenCoverWithOnDismiss(
                isPresented: reference,
                onDismiss: try replacingConstructorMarkers(
                    in: program,
                    itemsByMarker: itemsByMarker,
                    definitions: definitions
                ),
                content: try replacingConstructorMarkers(
                    in: content,
                    itemsByMarker: itemsByMarker,
                    definitions: definitions
                )
            )

        default:
            return modifier
        }
    }

    private func replacingConstructorMarkers(
        in program: PreviewActionProgram,
        itemsByMarker: [String: PreviewIdentifiableItem],
        definitions: [PreviewStateDefinition]
    ) throws -> PreviewActionProgram {
        let actions = program.actions.map { action in
            switch action {
            case .set(
                let stateName,
                .string(let marker)
            ) where itemsByMarker[marker] != nil:
                return PreviewAction.set(
                    stateName: stateName,
                    value: .identifiableItem(
                        itemsByMarker[marker]!
                    )
                )

            default:
                return action
            }
        }

        let rewritten = PreviewActionProgram(
            actions: actions
        )

        try PreviewActionValidator.validate(
            rewritten,
            definitions: definitions
        )

        return rewritten
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

private struct PreviewIdentifiableConstructorMemberSchema {
    let name: String
    let typeName: String
}

private struct PreviewIdentifiableConstructorModelSchema {
    let typeName: String
    let members: [PreviewIdentifiableConstructorMemberSchema]
}

private struct PreviewIdentifiableConstructorStateSchema {
    let stateName: String
    let modelTypeName: String
}

private struct PreviewIdentifiableConstructorRewrite {
    let source: String
    let itemsByMarker: [String: PreviewIdentifiableItem]
}

private enum PreviewIdentifiableConstructorError: Error {
    case malformedModel(String)
    case missingID(String)
    case unsupportedMember(
        model: String,
        member: String,
        type: String
    )
    case assignmentTypeMismatch(
        state: String,
        expected: String,
        actual: String
    )
    case malformedConstructor(String)
    case unknownArgument(
        model: String,
        argument: String
    )
    case duplicateArgument(
        model: String,
        argument: String
    )
    case missingArgument(
        model: String,
        argument: String
    )
    case invalidLiteral(
        model: String,
        argument: String,
        expectedType: String
    )
}

extension PreviewIdentifiableConstructorError: LocalizedError {
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

        case .assignmentTypeMismatch(
            let state,
            let expected,
            let actual
        ):
            return
                "Identifiable preview @State '\(state)' expects '\(expected)' but the action constructs '\(actual)'."

        case .malformedConstructor(let model):
            return
                "Identifiable preview model constructor '\(model)(...)' is malformed."

        case .unknownArgument(
            let model,
            let argument
        ):
            return
                "Identifiable preview model '\(model)' has no stored member named '\(argument)'."

        case .duplicateArgument(
            let model,
            let argument
        ):
            return
                "Identifiable preview model '\(model)' constructor repeats argument '\(argument)'."

        case .missingArgument(
            let model,
            let argument
        ):
            return
                "Identifiable preview model '\(model)' constructor is missing argument '\(argument)'."

        case .invalidLiteral(
            let model,
            let argument,
            let expectedType
        ):
            return
                "Identifiable preview model '\(model)' argument '\(argument)' must be a portable \(expectedType) literal."
        }
    }
}

private struct PreviewIdentifiableConstructorSourceRewriter {
    let source: String

    func rewrite() throws -> PreviewIdentifiableConstructorRewrite {
        let models = try scanModels()

        guard !models.isEmpty else {
            return PreviewIdentifiableConstructorRewrite(
                source: source,
                itemsByMarker: [:]
            )
        }

        let states = try scanStates(
            models: models
        )

        guard !states.isEmpty else {
            return PreviewIdentifiableConstructorRewrite(
                source: source,
                itemsByMarker: [:]
            )
        }

        let assignmentPattern =
            #"\b([A-Za-z_][A-Za-z0-9_]*)\s*=\s*([A-Za-z_][A-Za-z0-9_]*)\s*\("#
        let regex = try NSRegularExpression(
            pattern: assignmentPattern
        )
        let nsSource = source as NSString
        let matches = regex.matches(
            in: source,
            range: NSRange(
                location: 0,
                length: nsSource.length
            )
        )

        var replacements: [(NSRange, String)] = []
        var itemsByMarker: [String: PreviewIdentifiableItem] = [:]

        for match in matches {
            guard match.numberOfRanges >= 3,
                  isCodeLocation(match.range.location) else {
                continue
            }

            let stateName = nsSource.substring(
                with: match.range(at: 1)
            )

            guard let state = states[stateName] else {
                continue
            }

            let actualType = nsSource.substring(
                with: match.range(at: 2)
            )

            guard actualType == state.modelTypeName else {
                throw PreviewIdentifiableConstructorError
                    .assignmentTypeMismatch(
                        state: stateName,
                        expected: state.modelTypeName,
                        actual: actualType
                    )
            }

            guard let model = models[actualType] else {
                continue
            }

            let openParenLocation = NSMaxRange(match.range) - 1

            guard let closeParenLocation = matchingDelimiterLocation(
                openingLocation: openParenLocation,
                open: 40,
                close: 41
            ) else {
                throw PreviewIdentifiableConstructorError
                    .malformedConstructor(actualType)
            }

            let argumentsRange = NSRange(
                location: openParenLocation + 1,
                length: closeParenLocation - openParenLocation - 1
            )
            let argumentsSource = nsSource.substring(
                with: argumentsRange
            )

            let item = try parseItem(
                model: model,
                argumentsSource: argumentsSource
            )

            let marker =
                "__ISWIFT_IDENTIFIABLE_ITEM_ASSIGN_\(itemsByMarker.count)__"
            itemsByMarker[marker] = item

            let replacementRange = NSRange(
                location: match.range(at: 2).location,
                length: closeParenLocation - match.range(at: 2).location + 1
            )
            replacements.append(
                (
                    replacementRange,
                    "\"\(marker)\""
                )
            )
        }

        guard !replacements.isEmpty else {
            return PreviewIdentifiableConstructorRewrite(
                source: source,
                itemsByMarker: [:]
            )
        }

        let mutable = NSMutableString(
            string: source
        )

        for replacement in replacements.sorted(
            by: { $0.0.location > $1.0.location }
        ) {
            mutable.replaceCharacters(
                in: replacement.0,
                with: replacement.1
            )
        }

        return PreviewIdentifiableConstructorRewrite(
            source: mutable as String,
            itemsByMarker: itemsByMarker
        )
    }

    private func scanStates(
        models: [String: PreviewIdentifiableConstructorModelSchema]
    ) throws -> [String: PreviewIdentifiableConstructorStateSchema] {
        let pattern =
            #"@State\s+(?:(?:private|fileprivate|internal|public)\s+)?var\s+([A-Za-z_][A-Za-z0-9_]*)\s*:\s*([A-Za-z_][A-Za-z0-9_]*)\s*\?\s*=\s*nil"#
        let regex = try NSRegularExpression(
            pattern: pattern
        )
        let nsSource = source as NSString
        let matches = regex.matches(
            in: source,
            range: NSRange(
                location: 0,
                length: nsSource.length
            )
        )

        var result: [String: PreviewIdentifiableConstructorStateSchema] = [:]

        for match in matches {
            guard match.numberOfRanges >= 3,
                  isCodeLocation(match.range.location) else {
                continue
            }

            let stateName = nsSource.substring(
                with: match.range(at: 1)
            )
            let typeName = nsSource.substring(
                with: match.range(at: 2)
            )

            guard models[typeName] != nil else {
                continue
            }

            result[stateName] =
                PreviewIdentifiableConstructorStateSchema(
                    stateName: stateName,
                    modelTypeName: typeName
                )
        }

        return result
    }

    private func scanModels() throws
        -> [String: PreviewIdentifiableConstructorModelSchema] {
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

        var result: [String: PreviewIdentifiableConstructorModelSchema] = [:]

        for match in matches {
            guard match.numberOfRanges >= 3,
                  isCodeLocation(match.range.location) else {
                continue
            }

            let typeName = nsSource.substring(
                with: match.range(at: 1)
            )
            let conformances = nsSource.substring(
                with: match.range(at: 2)
            )
                .split(separator: ",")
                .map {
                    $0.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                }

            guard conformances.contains("Identifiable") else {
                continue
            }

            let openBraceLocation = NSMaxRange(match.range) - 1

            guard let closeBraceLocation = matchingDelimiterLocation(
                openingLocation: openBraceLocation,
                open: 123,
                close: 125
            ) else {
                throw PreviewIdentifiableConstructorError
                    .malformedModel(typeName)
            }

            let bodyRange = NSRange(
                location: openBraceLocation + 1,
                length: closeBraceLocation - openBraceLocation - 1
            )
            let body = nsSource.substring(
                with: bodyRange
            )
            let members = try scanMembers(
                modelName: typeName,
                body: body
            )

            guard members.contains(
                where: { $0.name == "id" }
            ) else {
                throw PreviewIdentifiableConstructorError
                    .missingID(typeName)
            }

            result[typeName] =
                PreviewIdentifiableConstructorModelSchema(
                    typeName: typeName,
                    members: members
                )
        }

        return result
    }

    private func scanMembers(
        modelName: String,
        body: String
    ) throws -> [PreviewIdentifiableConstructorMemberSchema] {
        let pattern =
            #"\b(?:let|var)\s+([A-Za-z_][A-Za-z0-9_]*)\s*:\s*([A-Za-z_][A-Za-z0-9_]*)"#
        let regex = try NSRegularExpression(
            pattern: pattern
        )
        let nsBody = body as NSString
        let matches = regex.matches(
            in: body,
            range: NSRange(
                location: 0,
                length: nsBody.length
            )
        )

        let supported: Set<String> = [
            "String",
            "Bool",
            "Int",
            "Double",
            "Float"
        ]
        var result: [PreviewIdentifiableConstructorMemberSchema] = []

        for match in matches {
            guard match.numberOfRanges >= 3 else {
                continue
            }

            let name = nsBody.substring(
                with: match.range(at: 1)
            )
            let typeName = nsBody.substring(
                with: match.range(at: 2)
            )

            guard supported.contains(typeName) else {
                throw PreviewIdentifiableConstructorError
                    .unsupportedMember(
                        model: modelName,
                        member: name,
                        type: typeName
                    )
            }

            result.append(
                PreviewIdentifiableConstructorMemberSchema(
                    name: name,
                    typeName: typeName
                )
            )
        }

        return result
    }

    private func parseItem(
        model: PreviewIdentifiableConstructorModelSchema,
        argumentsSource: String
    ) throws -> PreviewIdentifiableItem {
        let parts = splitArguments(
            argumentsSource
        )
        var valuesByName: [String: PreviewItemMemberValue] = [:]
        let memberNames = Set(
            model.members.map(\.name)
        )

        for part in parts {
            guard let separator = firstTopLevelColon(
                in: part
            ) else {
                throw PreviewIdentifiableConstructorError
                    .malformedConstructor(model.typeName)
            }

            let name = String(
                part[..<separator]
            ).trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            let rawValue = String(
                part[part.index(after: separator)...]
            ).trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            guard memberNames.contains(name) else {
                throw PreviewIdentifiableConstructorError
                    .unknownArgument(
                        model: model.typeName,
                        argument: name
                    )
            }

            guard valuesByName[name] == nil else {
                throw PreviewIdentifiableConstructorError
                    .duplicateArgument(
                        model: model.typeName,
                        argument: name
                    )
            }

            guard let schema = model.members.first(
                where: { $0.name == name }
            ) else {
                throw PreviewIdentifiableConstructorError
                    .unknownArgument(
                        model: model.typeName,
                        argument: name
                    )
            }

            valuesByName[name] = try parseLiteral(
                rawValue,
                modelName: model.typeName,
                argumentName: name,
                expectedType: schema.typeName
            )
        }

        for member in model.members {
            guard valuesByName[member.name] != nil else {
                throw PreviewIdentifiableConstructorError
                    .missingArgument(
                        model: model.typeName,
                        argument: member.name
                    )
            }
        }

        guard let id = valuesByName["id"] else {
            throw PreviewIdentifiableConstructorError
                .missingArgument(
                    model: model.typeName,
                    argument: "id"
                )
        }

        let members = model.members.compactMap { member
            -> PreviewItemMember? in
            guard member.name != "id",
                  let value = valuesByName[member.name] else {
                return nil
            }

            return PreviewItemMember(
                name: member.name,
                value: value
            )
        }

        return PreviewIdentifiableItem(
            typeName: model.typeName,
            id: id,
            members: members
        )
    }

    private func parseLiteral(
        _ raw: String,
        modelName: String,
        argumentName: String,
        expectedType: String
    ) throws -> PreviewItemMemberValue {
        switch expectedType {
        case "String":
            guard raw.first == "\"",
                  raw.last == "\"",
                  raw.count >= 2 else {
                throw PreviewIdentifiableConstructorError
                    .invalidLiteral(
                        model: modelName,
                        argument: argumentName,
                        expectedType: expectedType
                    )
            }

            return .string(
                unescapeString(
                    String(
                        raw.dropFirst().dropLast()
                    )
                )
            )

        case "Bool":
            if raw == "true" {
                return .bool(true)
            }

            if raw == "false" {
                return .bool(false)
            }

        case "Int":
            if raw.range(
                of: #"^-?\d+$"#,
                options: .regularExpression
            ) != nil,
               let value = Double(raw) {
                return .number(value)
            }

        case "Double", "Float":
            if raw.range(
                of: #"^-?(?:\d+(?:\.\d*)?|\.\d+)$"#,
                options: .regularExpression
            ) != nil,
               let value = Double(raw) {
                return .number(value)
            }

        default:
            break
        }

        throw PreviewIdentifiableConstructorError
            .invalidLiteral(
                model: modelName,
                argument: argumentName,
                expectedType: expectedType
            )
    }

    private func splitArguments(
        _ text: String
    ) -> [String] {
        var result: [String] = []
        var start = text.startIndex
        var index = text.startIndex
        var parenDepth = 0
        var braceDepth = 0
        var bracketDepth = 0
        var inString = false
        var escaped = false

        while index < text.endIndex {
            let character = text[index]

            if inString {
                if escaped {
                    escaped = false
                } else if character == "\\" {
                    escaped = true
                } else if character == "\"" {
                    inString = false
                }

                index = text.index(after: index)
                continue
            }

            switch character {
            case "\"":
                inString = true

            case "(":
                parenDepth += 1

            case ")":
                parenDepth = max(0, parenDepth - 1)

            case "{":
                braceDepth += 1

            case "}":
                braceDepth = max(0, braceDepth - 1)

            case "[":
                bracketDepth += 1

            case "]":
                bracketDepth = max(0, bracketDepth - 1)

            case "," where parenDepth == 0 &&
                            braceDepth == 0 &&
                            bracketDepth == 0:
                let part = String(text[start..<index])
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                if !part.isEmpty {
                    result.append(part)
                }
                start = text.index(after: index)

            default:
                break
            }

            index = text.index(after: index)
        }

        let tail = String(text[start...])
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
        if !tail.isEmpty {
            result.append(tail)
        }

        return result
    }

    private func firstTopLevelColon(
        in text: String
    ) -> String.Index? {
        var index = text.startIndex
        var inString = false
        var escaped = false
        var depth = 0

        while index < text.endIndex {
            let character = text[index]

            if inString {
                if escaped {
                    escaped = false
                } else if character == "\\" {
                    escaped = true
                } else if character == "\"" {
                    inString = false
                }

                index = text.index(after: index)
                continue
            }

            switch character {
            case "\"":
                inString = true

            case "(", "[", "{":
                depth += 1

            case ")", "]", "}":
                depth = max(0, depth - 1)

            case ":" where depth == 0:
                return index

            default:
                break
            }

            index = text.index(after: index)
        }

        return nil
    }

    private func unescapeString(
        _ value: String
    ) -> String {
        var output = ""
        var index = value.startIndex

        while index < value.endIndex {
            let character = value[index]

            guard character == "\\" else {
                output.append(character)
                index = value.index(after: index)
                continue
            }

            let next = value.index(after: index)
            guard next < value.endIndex else {
                output.append("\\")
                break
            }

            switch value[next] {
            case "n":
                output.append("\n")

            case "t":
                output.append("\t")

            case "\"":
                output.append("\"")

            case "\\":
                output.append("\\")

            default:
                output.append("\\")
                output.append(value[next])
            }

            index = value.index(after: next)
        }

        return output
    }

    private func matchingDelimiterLocation(
        openingLocation: Int,
        open: unichar,
        close: unichar
    ) -> Int? {
        let nsSource = source as NSString
        var index = openingLocation
        var depth = 0
        var inString = false
        var escaped = false
        var inLineComment = false
        var inBlockComment = false

        while index < nsSource.length {
            let scalar = nsSource.character(at: index)
            let next = index + 1 < nsSource.length
                ? nsSource.character(at: index + 1)
                : 0

            if inLineComment {
                if scalar == 10 {
                    inLineComment = false
                }
                index += 1
                continue
            }

            if inBlockComment {
                if scalar == 42 && next == 47 {
                    inBlockComment = false
                    index += 2
                    continue
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

            if scalar == 47 && next == 47 {
                inLineComment = true
                index += 2
                continue
            }

            if scalar == 47 && next == 42 {
                inBlockComment = true
                index += 2
                continue
            }

            if scalar == 34 {
                inString = true
                index += 1
                continue
            }

            if scalar == open {
                depth += 1
            } else if scalar == close {
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
        var inBlockComment = false

        while index < min(location, nsSource.length) {
            let scalar = nsSource.character(at: index)
            let next = index + 1 < nsSource.length
                ? nsSource.character(at: index + 1)
                : 0

            if inLineComment {
                if scalar == 10 {
                    inLineComment = false
                }
                index += 1
                continue
            }

            if inBlockComment {
                if scalar == 42 && next == 47 {
                    inBlockComment = false
                    index += 2
                    continue
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

            if scalar == 47 && next == 47 {
                inLineComment = true
                index += 2
                continue
            }

            if scalar == 47 && next == 42 {
                inBlockComment = true
                index += 2
                continue
            }

            if scalar == 34 {
                inString = true
                index += 1
                continue
            }

            index += 1
        }

        return !inString &&
            !inLineComment &&
            !inBlockComment
    }
}
