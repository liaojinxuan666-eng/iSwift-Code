import Foundation
import Combine

@MainActor
final class PreviewSessionViewModel: ObservableObject {
    @Published private(set) var document: PreviewDocument?
    @Published private(set) var diagnostics: [PreviewDiagnostic] = []
    @Published private(set) var isRefreshing = false
    @Published private(set) var refreshCount = 0
    @Published private(set) var lastRefreshDate: Date?

    private let provider: any PreviewProvider
    private var pendingRefreshTask: Task<Void, Never>?

    init(
        provider: any PreviewProvider =
            SwiftUIAnimationTransitionPreviewProvider()
    ) {
        self.provider = provider
    }

    func refresh(from snapshot: ProjectWorkspaceSnapshot) {
        cancelScheduledRefresh()
        performRefresh(from: snapshot)
    }

    /// Debounces preview generation without taking a workspace snapshot for
    /// every keystroke. The snapshot closure is evaluated only after the
    /// debounce delay has elapsed and only for the latest scheduled refresh.
    func scheduleRefresh(
        delayNanoseconds: UInt64 = 350_000_000,
        snapshotProvider: @escaping @MainActor () throws -> ProjectWorkspaceSnapshot
    ) {
        cancelScheduledRefresh()

        pendingRefreshTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: delayNanoseconds)
                guard !Task.isCancelled else { return }

                let snapshot = try snapshotProvider()
                guard !Task.isCancelled else { return }

                self?.pendingRefreshTask = nil
                self?.performRefresh(from: snapshot)
            } catch is CancellationError {
                return
            } catch {
                self?.pendingRefreshTask = nil
                self?.publish(error: error, filePath: nil)
            }
        }
    }

    func cancelScheduledRefresh() {
        pendingRefreshTask?.cancel()
        pendingRefreshTask = nil
    }

    private func performRefresh(from snapshot: ProjectWorkspaceSnapshot) {
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
            refreshCount += 1
            lastRefreshDate = Date()
        } catch {
            publish(
                error: error,
                filePath: snapshot.descriptor.entryFilePath?.value
            )
        }
    }

    private func publish(error: Error, filePath: String?) {
        document = nil
        diagnostics = [
            PreviewDiagnostic(
                severity: .error,
                message: error.localizedDescription,
                filePath: filePath
            )
        ]
        refreshCount += 1
        lastRefreshDate = Date()
        isRefreshing = false
    }
}
