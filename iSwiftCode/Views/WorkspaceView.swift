import SwiftUI

struct WorkspaceView: View {
    @StateObject private var model = EditorViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    compilerStatus
                    CodeEditorView(source: $model.source)
                        .frame(minHeight: 360)
                    ConsoleView(
                        output: model.consoleOutput,
                        diagnostics: model.diagnostics,
                        summary: model.buildSummary
                    )
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("iSwift Code")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("Restore Example", systemImage: "arrow.counterclockwise") {
                            model.restoreExample()
                        }
                        Button("IPA Export — Phase 2", systemImage: "shippingbox", action: {})
                            .disabled(true)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: model.run) {
                        Label(model.isRunning ? "Running" : "Run", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.isRunning)
                }
            }
        }
    }

    private var compilerStatus: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.shield.fill")
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text("Local Sandbox Compiler")
                    .font(.subheadline.weight(.semibold))
                Text("No cloud build • Swift Core MVP")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("0.1")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

#Preview {
    WorkspaceView()
}
