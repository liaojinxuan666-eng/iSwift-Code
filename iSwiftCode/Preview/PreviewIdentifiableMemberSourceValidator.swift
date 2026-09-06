import Foundation

/// One source-level custom item member that cannot be resolved against the
/// declared portable Identifiable model schema.
struct PreviewIdentifiableMemberValidationIssue:
    Equatable,
    Sendable,
    LocalizedError {
    let stateName: String
    let modelTypeName: String
    let memberName: String
    let availableMembers: [String]

    var errorDescription: String? {
        let available = availableMembers
            .sorted()
            .joined(separator: ", ")

        if available.isEmpty {
            return
                "Identifiable preview model '\(modelTypeName)' has no stored member '\(memberName)'."
        }

        return
            "Identifiable preview model '\(modelTypeName)' has no stored member '\(memberName)'. Available members: \(available)."
    }
}

enum PreviewIdentifiableMemberSourceValidationError:
    Error,
    LocalizedError {
    case malformedPresentation

    var errorDescription: String? {
        switch self {
        case .malformedPresentation:
            return
                "Identifiable item member validation found a malformed item presentation closure."
        }
    }
}

/// Validates direct and interpolated `item.member` references before the
/// established preview-provider stack lowers them.
///
/// The validator reads only source text. It never executes the source model,
/// property getters, presentation closures, or interpolation expressions.
struct PreviewIdentifiableMemberSourceValidator {
    let source: String

    func validate() throws
        -> [PreviewIdentifiableMemberValidationIssue] {
        let schemas = try scanSchemas()

        guard !schemas.isEmpty else {
            return []
        }

        let states = try scanCustomOptionalStates(
            schemas: schemas
        )

        guard !states.isEmpty else {
            return []
        }

        let presentations =
            try scanPresentations()

        var issues:
            [PreviewIdentifiableMemberValidationIssue] = []
        var seen = Set<String>()

        for presentation in presentations {
            guard let modelTypeName =
                    states[presentation.stateName],
                  let schema =
                    schemas[modelTypeName] else {
                // Primitive item state and unsupported source models remain on
                // the existing provider paths.
                continue
            }

            let references =
                try scanMemberReferences(
                    in: presentation
                )

            for memberName in references {
                guard !schema.members.contains(
                    memberName
                ) else {
                    continue
                }

                let key =
                    presentation.stateName +
                    "|" +
                    modelTypeName +
                    "|" +
                    memberName

                guard !seen.contains(key) else {
                    continue
                }

                seen.insert(key)

                issues.append(
                    PreviewIdentifiableMemberValidationIssue(
                        stateName:
                            presentation.stateName,
                        modelTypeName:
                            modelTypeName,
                        memberName:
                            memberName,
                        availableMembers:
                            Array(schema.members)
                    )
                )
            }
        }

        return issues
    }

    private func scanSchemas() throws
        -> [String: PreviewSourceItemSchema] {
        let pattern =
            #"\bstruct\s+([A-Za-z_][A-Za-z0-9_]*)\s*:\s*([^{]+)\{"#

        let regex =
            try NSRegularExpression(
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

        var result:
            [String: PreviewSourceItemSchema] = [:]

        for match in matches {
            guard match.numberOfRanges >= 3,
                  lexicalState(
                    at: match.range.location
                  ) == .code else {
                continue
            }

            let typeName =
                nsSource.substring(
                    with: match.range(at: 1)
                )

            let conformances =
                nsSource.substring(
                    with: match.range(at: 2)
                )
                .split(separator: ",")
                .map {
                    $0.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                }

            guard conformances.contains(
                "Identifiable"
            ) else {
                continue
            }

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
                continue
            }

            let openingBrace =
                match.range.location +
                braceInHeader.location

            guard let closingBrace =
                    matchingBraceLocation(
                        openingBrace
                    ) else {
                continue
            }

            let bodyStart =
                openingBrace + 1

            let body =
                nsSource.substring(
                    with: NSRange(
                        location: bodyStart,
                        length:
                            closingBrace -
                            bodyStart
                    )
                )

            let memberPattern =
                #"\b(?:let|var)\s+([A-Za-z_][A-Za-z0-9_]*)\s*:"#

            let memberRegex =
                try NSRegularExpression(
                    pattern: memberPattern
                )

            let nsBody = body as NSString
            let memberMatches =
                memberRegex.matches(
                    in: body,
                    range: NSRange(
                        location: 0,
                        length:
                            nsBody.length
                    )
                )

            var members = Set<String>()

            for memberMatch in memberMatches {
                guard memberMatch.numberOfRanges >= 2 else {
                    continue
                }

                members.insert(
                    nsBody.substring(
                        with:
                            memberMatch.range(at: 1)
                    )
                )
            }

            result[typeName] =
                PreviewSourceItemSchema(
                    typeName: typeName,
                    members: members
                )
        }

        return result
    }

    private func scanCustomOptionalStates(
        schemas:
            [String: PreviewSourceItemSchema]
    ) throws -> [String: String] {
        let pattern =
            #"@State\s+(?:(?:private|fileprivate|internal|public)\s+)?var\s+([A-Za-z_][A-Za-z0-9_]*)\s*:\s*([A-Za-z_][A-Za-z0-9_]*)\s*\?\s*=\s*nil"#

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

        var result:
            [String: String] = [:]

        for match in matches {
            guard match.numberOfRanges >= 3,
                  lexicalState(
                    at: match.range.location
                  ) == .code else {
                continue
            }

            let stateName =
                nsSource.substring(
                    with:
                        match.range(at: 1)
                )
            let typeName =
                nsSource.substring(
                    with:
                        match.range(at: 2)
                )

            guard schemas[typeName] != nil else {
                continue
            }

            result[stateName] =
                typeName
        }

        return result
    }

    private func scanPresentations() throws
        -> [PreviewSourceItemPresentation] {
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

        var result:
            [PreviewSourceItemPresentation] = []

        for match in matches {
            guard match.numberOfRanges >= 3,
                  lexicalState(
                    at: match.range.location
                  ) == .code else {
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
                    PreviewIdentifiableMemberSourceValidationError
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
                    PreviewIdentifiableMemberSourceValidationError
                        .malformedPresentation
            }

            let contentStart =
                NSMaxRange(match.range)

            guard closingBrace >= contentStart else {
                throw
                    PreviewIdentifiableMemberSourceValidationError
                        .malformedPresentation
            }

            result.append(
                PreviewSourceItemPresentation(
                    stateName: stateName,
                    itemName: itemName,
                    contentRange: NSRange(
                        location:
                            contentStart,
                        length:
                            closingBrace -
                            contentStart
                    )
                )
            )
        }

        return result
    }

    private func scanMemberReferences(
        in presentation:
            PreviewSourceItemPresentation
    ) throws -> [String] {
        let nsSource = source as NSString
        let content =
            nsSource.substring(
                with:
                    presentation.contentRange
            )
        let nsContent =
            content as NSString

        let escapedItem =
            NSRegularExpression
                .escapedPattern(
                    for:
                        presentation.itemName
                )

        let directPattern =
            #"Text\s*\(\s*"# +
            escapedItem +
            #"\s*\.\s*([A-Za-z_][A-Za-z0-9_]*)\s*\)"#

        let interpolationPattern =
            #"\\\(\s*"# +
            escapedItem +
            #"\s*\.\s*([A-Za-z_][A-Za-z0-9_]*)\s*\)"#

        let directRegex =
            try NSRegularExpression(
                pattern: directPattern
            )
        let interpolationRegex =
            try NSRegularExpression(
                pattern:
                    interpolationPattern
            )

        var result: [String] = []

        for match in directRegex.matches(
            in: content,
            range: NSRange(
                location: 0,
                length:
                    nsContent.length
            )
        ) {
            guard match.numberOfRanges >= 2 else {
                continue
            }

            let absoluteLocation =
                presentation
                    .contentRange
                    .location +
                match.range.location

            guard lexicalState(
                at: absoluteLocation
            ) == .code else {
                continue
            }

            result.append(
                nsContent.substring(
                    with:
                        match.range(at: 1)
                )
            )
        }

        for match in interpolationRegex.matches(
            in: content,
            range: NSRange(
                location: 0,
                length:
                    nsContent.length
            )
        ) {
            guard match.numberOfRanges >= 2 else {
                continue
            }

            let absoluteLocation =
                presentation
                    .contentRange
                    .location +
                match.range.location

            guard lexicalState(
                at: absoluteLocation
            ) == .string else {
                continue
            }

            result.append(
                nsContent.substring(
                    with:
                        match.range(at: 1)
                )
            )
        }

        return result
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

    private func lexicalState(
        at location: Int
    ) -> PreviewSourceLexicalState {
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

private struct PreviewSourceItemSchema {
    let typeName: String
    let members: Set<String>
}

private struct PreviewSourceItemPresentation {
    let stateName: String
    let itemName: String
    let contentRange: NSRange
}

private enum PreviewSourceLexicalState {
    case code
    case string
    case lineComment
}
