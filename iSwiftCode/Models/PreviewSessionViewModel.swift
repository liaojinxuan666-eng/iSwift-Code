import Foundation
import Combine

@MainActor
final class PreviewSessionViewModel: ObservableObject {
    @Published private(set) var document: PreviewDocument?
    @Published private(set) var diagnostics: [PreviewDiagnostic] = []
    @Published private(set) var isRefreshing = false

    private let provider: any PreviewProvider

    init(provider: any PreviewProvider = SwiftUIPreviewProvider()) {
        self.provider = provider
    }

    func refresh(from snapshot: ProjectWorkspaceSnapshot) {
        isRefreshing = true
        defer { isRefreshing = false }

        let files = snapshot.files.compactMap { file -> PreviewSourceFile? in
            guard let text = file.text else { return nil }
            return PreviewSourceFile(path: file.path.value, contents: text)
        }

        let request = PreviewRequest(
            files: files,
            entryFilePath: snapshot.descriptor.entryFilePath?.value
        )

        do {
            let result = try provider.makePreview(request)
            document = result.document
            diagnostics = result.diagnostics
        } catch {
            document = nil
            diagnostics = [
                PreviewDiagnostic(
                    severity: .error,
                    message: error.localizedDescription,
                    filePath: snapshot.descriptor.entryFilePath?.value
                )
            ]
        }
    }
}
