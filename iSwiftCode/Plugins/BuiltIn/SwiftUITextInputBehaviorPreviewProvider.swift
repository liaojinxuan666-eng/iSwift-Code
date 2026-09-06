import Foundation

/// Adds portable text-input behavior on top of the established conditional
/// preview stack.
///
/// Supported source forms:
///
/// ```swift
/// SecureField("Password", text: $password)
///
/// TextField("Email", text: $email)
///     .keyboardType(.emailAddress)
///     .textInputAutocapitalization(.never)
///     .autocorrectionDisabled()
///     .submitLabel(.done)
///
/// Toggle("Remember", isOn: $remember)
///     .labelsHidden()
/// ```
///
/// Modifiers are rewritten to parser-safe markers before the existing provider
/// stack runs. SecureField is rewritten through the established TextField
/// binding path and restored to a dedicated portable node afterward.
final class SwiftUITextInputBehaviorPreviewProvider:
    PreviewProvider {
    private let base =
        SwiftUIConditionalPreviewProvider()

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

        let selected =
            request.files[selectedIndex]

        let rewrite:
            PreviewTextInputSourceRewrite

        do {
            rewrite =
                try PreviewTextInputSourceRewriter(
                    source: selected.contents
                ).rewrite()
        } catch {
            return diagnosticResult(
                error,
                filePath: selected.path
            )
        }

        guard rewrite.hasChanges else {
            return try base.makePreview(request)
        }

        var files = request.files
        files[selectedIndex] =
            PreviewSourceFile(
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

        return PreviewProviderResult(
            document: PreviewDocument(
                root: replacingMarkers(
                    in: document.root,
                    secureFieldMarkers:
                        rewrite.secureFieldMarkers,
                    modifierMarkers:
                        rewrite.modifierMarkers
                ),
                stateDefinitions:
                    document.stateDefinitions,
                sourceFilePath:
                    document.sourceFilePath,
                title: document.title
            ),
            diagnostics: result.diagnostics
        )
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

    private func replacingMarkers(
        in node: PreviewNode,
        secureFieldMarkers: [String: String],
        modifierMarkers:
            [String: PreviewTextInputModifierSpec]
    ) -> PreviewNode {
        switch node {
        case .textField(
            let prompt,
            let text
        ):
            if let originalPrompt =
                    secureFieldMarkers[prompt] {
                return .secureField(
                    prompt: originalPrompt,
                    text: text
                )
            }
            return node

        case .vStack(let children):
            return .vStack(
                children: children.map {
                    replacingMarkers(
                        in: $0,
                        secureFieldMarkers:
                            secureFieldMarkers,
                        modifierMarkers:
                            modifierMarkers
                    )
                }
            )

        case .hStack(let children):
            return .hStack(
                children: children.map {
                    replacingMarkers(
                        in: $0,
                        secureFieldMarkers:
                            secureFieldMarkers,
                        modifierMarkers:
                            modifierMarkers
                    )
                }
            )

        case .zStack(let children):
            return .zStack(
                children: children.map {
                    replacingMarkers(
                        in: $0,
                        secureFieldMarkers:
                            secureFieldMarkers,
                        modifierMarkers:
                            modifierMarkers
                    )
                }
            )

        case .scrollView(let children):
            return .scrollView(
                children: children.map {
                    replacingMarkers(
                        in: $0,
                        secureFieldMarkers:
                            secureFieldMarkers,
                        modifierMarkers:
                            modifierMarkers
                    )
                }
            )

        case .list(let children):
            return .list(
                children: children.map {
                    replacingMarkers(
                        in: $0,
                        secureFieldMarkers:
                            secureFieldMarkers,
                        modifierMarkers:
                            modifierMarkers
                    )
                }
            )

        case .navigationStack(let children):
            return .navigationStack(
                children: children.map {
                    replacingMarkers(
                        in: $0,
                        secureFieldMarkers:
                            secureFieldMarkers,
                        modifierMarkers:
                            modifierMarkers
                    )
                }
            )

        case .navigationLink(
            let title,
            let destination
        ):
            return .navigationLink(
                title: title,
                destination: replacingMarkers(
                    in: destination,
                    secureFieldMarkers:
                        secureFieldMarkers,
                    modifierMarkers:
                        modifierMarkers
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
                    replacingMarkers(
                        in: $0,
                        secureFieldMarkers:
                            secureFieldMarkers,
                        modifierMarkers:
                            modifierMarkers
                    )
                },
                whenFalse: whenFalse.map {
                    replacingMarkers(
                        in: $0,
                        secureFieldMarkers:
                            secureFieldMarkers,
                        modifierMarkers:
                            modifierMarkers
                    )
                }
            )

        case .modified(
            let baseNode,
            let modifiers
        ):
            return .modified(
                base: replacingMarkers(
                    in: baseNode,
                    secureFieldMarkers:
                        secureFieldMarkers,
                    modifierMarkers:
                        modifierMarkers
                ),
                modifiers: modifiers.map {
                    replacingMarker(
                        in: $0,
                        secureFieldMarkers:
                            secureFieldMarkers,
                        modifierMarkers:
                            modifierMarkers
                    )
                }
            )

        default:
            return node
        }
    }

    private func replacingMarker(
        in modifier: PreviewModifier,
        secureFieldMarkers: [String: String],
        modifierMarkers:
            [String: PreviewTextInputModifierSpec]
    ) -> PreviewModifier {
        switch modifier {
        case .navigationTitle(let title):
            guard let marker =
                    modifierMarkers[title] else {
                return modifier
            }

            switch marker {
            case .autocapitalization(let value):
                return .textInputAutocapitalization(
                    value
                )
            case .keyboardType(let value):
                return .keyboardType(value)
            case .autocorrectionDisabled(
                let disabled
            ):
                return .autocorrectionDisabled(
                    disabled
                )
            case .submitLabel(let value):
                return .submitLabel(value)
            case .labelsHidden:
                return .labelsHidden
            }

        case .sheet(
            let reference,
            let content
        ):
            return .sheet(
                isPresented: reference,
                content: replacingMarkers(
                    in: content,
                    secureFieldMarkers:
                        secureFieldMarkers,
                    modifierMarkers:
                        modifierMarkers
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
                content: replacingMarkers(
                    in: content,
                    secureFieldMarkers:
                        secureFieldMarkers,
                    modifierMarkers:
                        modifierMarkers
                )
            )

        case .fullScreenCover(
            let reference,
            let content
        ):
            return .fullScreenCover(
                isPresented: reference,
                content: replacingMarkers(
                    in: content,
                    secureFieldMarkers:
                        secureFieldMarkers,
                    modifierMarkers:
                        modifierMarkers
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
                content: replacingMarkers(
                    in: content,
                    secureFieldMarkers:
                        secureFieldMarkers,
                    modifierMarkers:
                        modifierMarkers
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

enum PreviewTextInputModifierSpec:
    Equatable,
    Sendable {
    case autocapitalization(
        PreviewTextInputAutocapitalization
    )
    case keyboardType(PreviewKeyboardType)
    case autocorrectionDisabled(Bool)
    case submitLabel(PreviewSubmitLabel)
    case labelsHidden
}

struct PreviewTextInputSourceRewrite:
    Equatable,
    Sendable {
    let source: String
    let secureFieldMarkers: [String: String]
    let modifierMarkers:
        [String: PreviewTextInputModifierSpec]

    var hasChanges: Bool {
        !secureFieldMarkers.isEmpty ||
        !modifierMarkers.isEmpty
    }
}

enum PreviewTextInputSourceError:
    Error,
    Equatable,
    Sendable {
    case malformedSecureField
}

extension PreviewTextInputSourceError:
    LocalizedError {
    var errorDescription: String? {
        switch self {
        case .malformedSecureField:
            return "SecureField preview must use a literal prompt and a simple `$state` String binding."
        }
    }
}

struct PreviewTextInputSourceRewriter {
    let source: String

    func rewrite() throws
        -> PreviewTextInputSourceRewrite {
        var secureFieldMarkers:
            [String: String] = [:]

        let secureRewritten =
            try rewriteSecureFields(
                in: source,
                markers:
                    &secureFieldMarkers
            )

        var modifierMarkers:
            [String: PreviewTextInputModifierSpec] = [:]

        let finalSource =
            try rewriteModifiers(
                in: secureRewritten,
                markers:
                    &modifierMarkers
            )

        return PreviewTextInputSourceRewrite(
            source: finalSource,
            secureFieldMarkers:
                secureFieldMarkers,
            modifierMarkers:
                modifierMarkers
        )
    }

    private func rewriteSecureFields(
        in input: String,
        markers:
            inout [String: String]
    ) throws -> String {
        let pattern =
            #"SecureField\s*\(\s*"((?:\\.|[^"])*)"\s*,\s*text\s*:\s*\$([A-Za-z_][A-Za-z0-9_]*)\s*\)"#

        let regex =
            try NSRegularExpression(
                pattern: pattern
            )
        let nsInput = input as NSString

        let matches = regex.matches(
            in: input,
            range: NSRange(
                location: 0,
                length: nsInput.length
            )
        ).filter {
            lexicalState(
                in: input,
                atUTF16Location:
                    $0.range.location
            ) == .code
        }

        guard !matches.isEmpty else {
            return input
        }

        let mutable =
            NSMutableString(string: input)

        for match in matches.reversed() {
            guard match.numberOfRanges >= 3 else {
                throw PreviewTextInputSourceError
                    .malformedSecureField
            }

            let prompt = unescapeString(
                nsInput.substring(
                    with: match.range(at: 1)
                )
            )
            let stateName =
                nsInput.substring(
                    with: match.range(at: 2)
                )

            let marker =
                "__ISWIFT_SECURE_FIELD_\(markers.count)__"

            markers[marker] = prompt

            mutable.replaceCharacters(
                in: match.range,
                with:
                    "TextField(\"\(marker)\", text: $\(stateName))"
            )
        }

        return mutable as String
    }

    private func rewriteModifiers(
        in input: String,
        markers:
            inout [String: PreviewTextInputModifierSpec]
    ) throws -> String {
        var replacements:
            [PreviewTextInputReplacement] = []
        let nsInput = input as NSString

        func collect(
            pattern: String,
            makeSpec:
                (NSTextCheckingResult, NSString)
                    -> PreviewTextInputModifierSpec?
        ) throws {
            let regex =
                try NSRegularExpression(
                    pattern: pattern
                )

            for match in regex.matches(
                in: input,
                range: NSRange(
                    location: 0,
                    length: nsInput.length
                )
            ) {
                guard lexicalState(
                    in: input,
                    atUTF16Location:
                        match.range.location
                ) == .code,
                let spec =
                    makeSpec(match, nsInput) else {
                    continue
                }

                replacements.append(
                    PreviewTextInputReplacement(
                        range: match.range,
                        spec: spec
                    )
                )
            }
        }

        try collect(
            pattern:
                #"\.textInputAutocapitalization\s*\(\s*\.(never|words|sentences|characters)\s*\)"#
        ) { match, ns in
            guard match.numberOfRanges >= 2 else {
                return nil
            }
            let raw = ns.substring(
                with: match.range(at: 1)
            )
            guard let value =
                    PreviewTextInputAutocapitalization(
                        rawValue: raw
                    ) else {
                return nil
            }
            return .autocapitalization(value)
        }

        try collect(
            pattern:
                #"\.keyboardType\s*\(\s*\.(default|asciiCapable|numbersAndPunctuation|URL|numberPad|phonePad|namePhonePad|emailAddress|decimalPad|twitter|webSearch|asciiCapableNumberPad)\s*\)"#
        ) { match, ns in
            guard match.numberOfRanges >= 2 else {
                return nil
            }
            let raw = ns.substring(
                with: match.range(at: 1)
            )
            let normalized =
                raw == "URL" ? "url" : raw
            guard let value =
                    PreviewKeyboardType(
                        rawValue: normalized
                    ) else {
                return nil
            }
            return .keyboardType(value)
        }

        try collect(
            pattern:
                #"\.autocorrectionDisabled\s*\(\s*(?:(true|false)\s*)?\)"#
        ) { match, ns in
            let disabled: Bool
            if match.numberOfRanges >= 2,
               match.range(at: 1).location !=
                    NSNotFound {
                disabled =
                    ns.substring(
                        with: match.range(at: 1)
                    ) == "true"
            } else {
                disabled = true
            }
            return .autocorrectionDisabled(
                disabled
            )
        }

        try collect(
            pattern:
                #"\.submitLabel\s*\(\s*\.(done|go|send|join|route|search|return|next|continue)\s*\)"#
        ) { match, ns in
            guard match.numberOfRanges >= 2 else {
                return nil
            }
            let raw = ns.substring(
                with: match.range(at: 1)
            )
            guard let value =
                    PreviewSubmitLabel(
                        rawValue: raw
                    ) else {
                return nil
            }
            return .submitLabel(value)
        }

        try collect(
            pattern:
                #"\.labelsHidden\s*\(\s*\)"#
        ) { _, _ in
            .labelsHidden
        }

        guard !replacements.isEmpty else {
            return input
        }

        // Reject overlapping matches rather than silently corrupting source.
        let sortedAscending =
            replacements.sorted {
                $0.range.location <
                    $1.range.location
            }

        var previousEnd = -1
        for replacement in sortedAscending {
            if replacement.range.location <
                previousEnd {
                continue
            }
            previousEnd =
                replacement.range.location +
                replacement.range.length

            let marker =
                "__ISWIFT_TEXT_INPUT_MODIFIER_\(markers.count)__"
            markers[marker] =
                replacement.spec
            replacement.marker = marker
        }

        let mutable =
            NSMutableString(string: input)

        let activeReplacements =
            sortedAscending
                .filter {
                    $0.marker != nil
                }
                .sorted(
                    by: {
                        $0.range.location >
                            $1.range.location
                    }
                )

        for replacement in activeReplacements {
            guard let marker =
                    replacement.marker else {
                continue
            }

            mutable.replaceCharacters(
                in: replacement.range,
                with:
                    ".navigationTitle(\"\(marker)\")"
            )
        }

        return mutable as String
    }

    private func unescapeString(
        _ value: String
    ) -> String {
        value
            .replacingOccurrences(
                of: #"\""#,
                with: #"""#
            )
            .replacingOccurrences(
                of: #"\\n"#,
                with: "\n"
            )
            .replacingOccurrences(
                of: #"\\t"#,
                with: "\t"
            )
            .replacingOccurrences(
                of: #"\\\\"#,
                with: #"\"#
            )
    }

    private func lexicalState(
        in input: String,
        atUTF16Location location: Int
    ) -> PreviewTextInputLexicalState {
        let nsInput = input as NSString
        var index = 0
        var inString = false
        var escaped = false
        var inLineComment = false
        var blockDepth = 0

        while index < location,
              index < nsInput.length {
            let scalar =
                nsInput.character(at: index)
            let next =
                index + 1 < nsInput.length
                    ? nsInput.character(
                        at: index + 1
                    )
                    : 0

            if inLineComment {
                if scalar == 10 {
                    inLineComment = false
                }
                index += 1
                continue
            }

            if blockDepth > 0 {
                if scalar == 47 &&
                   next == 42 {
                    blockDepth += 1
                    index += 2
                    continue
                }
                if scalar == 42 &&
                   next == 47 {
                    blockDepth -= 1
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

            if scalar == 34 {
                inString = true
                index += 1
                continue
            }

            if scalar == 47 &&
               next == 47 {
                inLineComment = true
                index += 2
                continue
            }

            if scalar == 47 &&
               next == 42 {
                blockDepth = 1
                index += 2
                continue
            }

            index += 1
        }

        if inLineComment {
            return .lineComment
        }
        if blockDepth > 0 {
            return .blockComment
        }
        if inString {
            return .string
        }
        return .code
    }
}

private final class PreviewTextInputReplacement {
    let range: NSRange
    let spec: PreviewTextInputModifierSpec
    var marker: String?

    init(
        range: NSRange,
        spec: PreviewTextInputModifierSpec
    ) {
        self.range = range
        self.spec = spec
    }
}

private enum PreviewTextInputLexicalState {
    case code
    case string
    case lineComment
    case blockComment
}
