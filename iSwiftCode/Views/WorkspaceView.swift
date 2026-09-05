import SwiftUI

struct WorkspaceView: View {
    @StateObject private var model: ProjectSessionViewModel
    @StateObject private var previewModel = PreviewSessionViewModel()

    @State private var isCreatingFile = false
    @State private var newFilePath = ""
    @State private var fileBeingRenamed: WorkspacePath?
    @State private var renameDestination = ""
    @State private var isShowingPreview = false

    init() {
        _model = StateObject(wrappedValue: ProjectSessionViewModel())
    }

    init(model: ProjectSessionViewModel) {
        _model = StateObject(wrappedValue: model)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                compilerStatus
                fileStrip

                HStack(spacing: 8) {
                    Image(systemName: fileIcon(for: model.activeFilePath))
                        .foregroundStyle(.secondary)
                    Text(model.activeFilePath?.value ?? "No file selected")
                        .font(.caption.monospaced())
                        .lineLimit(1)
                    if model.activeFilePath == model.entryFilePath {
                        Label("Entry", systemImage: "flag.fill")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    if model.isActiveFileDirty {
                        Text("Modified")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                    Spacer()
                    Button("Save") { perform { try model.saveActiveFile() } }
                        .font(.caption.weight(.semibold))
                        .disabled(model.activeFilePath == nil || !model.isActiveFileDirty)
                }

                CodeEditorView(source: $model.source)
                    .frame(minHeight: 360)
                    .disabled(model.activeFilePath == nil)

                ConsoleView(
                    output: model.consoleOutput,
                    diagnostics: model.diagnostics,
                    summary: model.buildSummary
                )
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(model.projectName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Button("New File", systemImage: "doc.badge.plus") {
                        newFilePath = ""
                        isCreatingFile = true
                    }
                    Button("Save All", systemImage: "square.and.arrow.down") {
                        perform { try model.saveAll() }
                    }
                    .disabled(model.dirtyFilePaths.isEmpty)
                    Divider()
                    Button("Restore Example", systemImage: "arrow.counterclockwise") {
                        model.restoreExample()
                    }
                    .disabled(model.entryFilePath == nil)
                    Button("App Preview", systemImage: "iphone") {
                        showPreview()
                    }
                    .disabled(model.files.isEmpty)
                    Button("IPA Export — Phase 2", systemImage: "shippingbox") {}
                        .disabled(true)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }

            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showPreview()
                } label: {
                    Image(systemName: "iphone")
                }
                .disabled(model.files.isEmpty)
                .accessibilityLabel("App Preview")

                Button(action: model.run) {
                    Label(model.isRunning ? "Running" : "Run", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isRunning || model.activeFilePath == nil)
            }
        }
        .sheet(isPresented: $isShowingPreview) {
            PreviewSheetView(model: previewModel) {
                showPreview()
            }
        }
        .alert("Create File", isPresented: $isCreatingFile) {
            TextField("Sources/Helper.swift", text: $newFilePath)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Cancel", role: .cancel) {}
            Button("Create") {
                perform {
                    let path = try WorkspacePath(newFilePath)
                    try model.createFile(at: path)
                }
            }
        } message: {
            Text("Enter a project-relative path.")
        }
        .alert(
            "Rename File",
            isPresented: Binding(
                get: { fileBeingRenamed != nil },
                set: { if !$0 { fileBeingRenamed = nil } }
            )
        ) {
            TextField("New path", text: $renameDestination)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Cancel", role: .cancel) { fileBeingRenamed = nil }
            Button("Rename") {
                guard let source = fileBeingRenamed else { return }
                perform {
                    let destination = try WorkspacePath(renameDestination)
                    try model.renameFile(from: source, to: destination)
                }
                fileBeingRenamed = nil
            }
        } message: {
            Text("Entry-file metadata is updated automatically when the entry file is renamed.")
        }
        .alert(
            "Project Error",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.clearError() } }
            )
        ) {
            Button("OK", role: .cancel) { model.clearError() }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private var fileStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(model.files, id: \.self) { path in
                    Button { perform { try model.selectFile(path) } } label: {
                        HStack(spacing: 6) {
                            Image(systemName: fileIcon(for: path)).font(.caption)
                            Text(path.fileName).font(.caption.monospaced()).lineLimit(1)
                            if path == model.entryFilePath { Image(systemName: "flag.fill").font(.caption2) }
                            if model.dirtyFilePaths.contains(path) { Circle().frame(width: 6, height: 6) }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                    }
                    .buttonStyle(.bordered)
                    .tint(model.activeFilePath == path ? .accentColor : .secondary)
                    .contextMenu {
                        Button("Set as Entry", systemImage: "flag") { perform { try model.setEntryFile(path) } }
                            .disabled(path == model.entryFilePath)
                        Button("Rename", systemImage: "pencil") {
                            fileBeingRenamed = path
                            renameDestination = path.value
                        }
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            perform { try model.deleteFile(at: path) }
                        }
                    }
                }

                Button {
                    newFilePath = ""
                    isCreatingFile = true
                } label: {
                    Image(systemName: "plus").frame(width: 24, height: 24)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Create file")
            }
        }
    }

    private var compilerStatus: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.shield.fill").foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text("Project Workspace").font(.subheadline.weight(.semibold))
                if let entryFilePath = model.entryFilePath {
                    Text("\(model.files.count) file(s) • Entry: \(entryFilePath.value)")
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                } else {
                    Text("\(model.files.count) file(s) • No entry file")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text("0.1.3-dev").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func showPreview() {
        do {
            previewModel.refresh(from: try model.snapshotIncludingUnsavedChanges())
            isShowingPreview = true
        } catch {
            model.present(error: error)
        }
    }

    private func fileIcon(for path: WorkspacePath?) -> String {
        guard let path else { return "doc" }
        switch path.pathExtension.lowercased() {
        case "swift": return "swift"
        case "c", "cc", "cpp", "cxx", "m", "mm": return "chevron.left.forwardslash.chevron.right"
        case "json", "plist": return "curlybraces"
        case "md", "txt": return "doc.text"
        default: return "doc"
        }
    }

    private func perform(_ operation: () throws -> Void) {
        do { try operation() } catch { model.present(error: error) }
    }
}

private struct PreviewSheetView: View {
    @ObservedObject var model: PreviewSessionViewModel
    let refresh: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let document = model.document {
                    PreviewRuntimeView(document: document)
                        .padding()
                } else {
                    ContentUnavailableView {
                        Label("Preview unavailable", systemImage: "iphone.slash")
                    } description: {
                        Text(model.diagnostics.first?.message ?? "No preview document was produced.")
                    }
                }
            }
            .navigationTitle("App Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Refresh", systemImage: "arrow.clockwise") { refresh() }
                }
            }
        }
    }
}

#Preview {
    NavigationStack { WorkspaceView() }
}
