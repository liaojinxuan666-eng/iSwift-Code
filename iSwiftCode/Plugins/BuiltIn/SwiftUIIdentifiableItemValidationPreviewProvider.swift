import Foundation

/// Validates custom Identifiable item member references before delegating to
/// the established interpolation/member/provider stack.
final class SwiftUIIdentifiableItemValidationPreviewProvider:
    PreviewProvider {
    private let base =
        SwiftUIIdentifiableItemInterpolationPreviewProvider()

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
        guard let selectedFile =
                selectedSourceFile(
                    in: request
                ) else {
            return try base.makePreview(request)
        }

        do {
            let issues =
                try PreviewIdentifiableMemberSourceValidator(
                    source:
                        selectedFile.contents
                ).validate()

            guard issues.isEmpty else {
                return PreviewProviderResult(
                    diagnostics:
                        issues.map {
                            PreviewDiagnostic(
                                severity: .error,
                                message:
                                    $0.localizedDescription,
                                filePath:
                                    selectedFile.path
                            )
                        }
                )
            }

            return try base.makePreview(request)
        } catch {
            return PreviewProviderResult(
                diagnostics: [
                    PreviewDiagnostic(
                        severity: .error,
                        message:
                            error.localizedDescription,
                        filePath:
                            selectedFile.path
                    )
                ]
            )
        }
    }

    private func selectedSourceFile(
        in request: PreviewRequest
    ) -> PreviewSourceFile? {
        if let entry =
                request.entryFilePath,
           let file =
                request.files.first(
                    where: {
                        $0.path == entry
                    }
                ) {
            return file
        }

        return request.files.first {
            $0.path
                .lowercased()
                .hasSuffix(".swift")
        }
    }
}
