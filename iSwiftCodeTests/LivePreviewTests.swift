import Foundation
import XCTest
@testable import iSwiftCode

final class LivePreviewTests: XCTestCase {
    @MainActor
    func testImmediateRefreshUpdatesDocumentAndMetrics() throws {
        let model = PreviewSessionViewModel()
        let snapshot = try makeSnapshot(source: "Text(\"Immediate\")")

        model.refresh(from: snapshot)

        XCTAssertEqual(model.document?.root, .text("Immediate"))
        XCTAssertEqual(model.refreshCount, 1)
        XCTAssertNotNil(model.lastRefreshDate)
        XCTAssertFalse(model.isRefreshing)
    }

    @MainActor
    func testScheduledRefreshDebouncesToLatestSource() async throws {
        let model = PreviewSessionViewModel()
        var source = "Text(\"First\")"

        model.scheduleRefresh(delayNanoseconds: 40_000_000) {
            try self.makeSnapshot(source: source)
        }

        source = "Text(\"Second\")"
        model.scheduleRefresh(delayNanoseconds: 1_000_000) {
            try self.makeSnapshot(source: source)
        }

        try await Task.sleep(nanoseconds: 80_000_000)

        XCTAssertEqual(model.document?.root, .text("Second"))
        XCTAssertEqual(model.refreshCount, 1)
    }

    @MainActor
    func testCancelledScheduledRefreshDoesNotRun() async throws {
        let model = PreviewSessionViewModel()

        model.scheduleRefresh(delayNanoseconds: 20_000_000) {
            try self.makeSnapshot(source: "Text(\"Cancelled\")")
        }
        model.cancelScheduledRefresh()

        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertNil(model.document)
        XCTAssertEqual(model.refreshCount, 0)
    }

    private func makeSnapshot(source: String) throws -> ProjectWorkspaceSnapshot {
        let path = try WorkspacePath("ContentView.swift")
        let descriptor = ProjectDescriptor(
            identifier: "tests.live-preview",
            displayName: "Live Preview Tests",
            entryFilePath: path
        )

        return ProjectWorkspaceSnapshot(
            descriptor: descriptor,
            files: [
                ProjectWorkspaceFile(
                    path: path,
                    data: Data(source.utf8)
                )
            ]
        )
    }
}
