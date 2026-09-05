import SwiftUI

struct WorkspaceView: View {
    @StateObject private var model = ProjectSessionViewModel()

    @State private var isCreatingFile = false
    @State private var newFilePath = ""

    @State private var fileBeingRenamed: WorkspacePath?
    @State private var renameDestination = ""

    var body: some View {
        NavigationStack {
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

                        if model.isActiveFileDirty {
                            Text("Modified")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.orange)
                        }

                        Spacer()

                        Button("Save") {
                            perform {
                                try model.saveActiveFile()
                            }
                        }
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
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("New File", systemImage: "doc.badge.plus") {
                            newFilePath = ""
                            isCreatingFile = true
                        }

                        Button("Save All", systemImage: "square.and.arrow.down") {
                            perform {
                                try model.saveAll()
                            }
                        }
                        .disabled(model.dirtyFilePaths.isEmpty)

                        Divider()

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
                        Label(
                            model.isRunning ? "Running" : "Run",
                            systemImage: "play.fill"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.isRunning || model.activeFilePath == nil)
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
                    set: { presented in
                        if !presented {
                            fileBeingRenamed = nil
                        }
                    }
                )
            ) {
                TextField("New path", text: $renameDestination)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Button("Cancel", role: .cancel) {
                    fileBeingRenamed = nil
                }

                Button("Rename") {
                    guard let source = fileBeingRenamed else { return }
                    perform {
                        let destination = try WorkspacePath(renameDestination)
                        try model.renameFile(from: source, to: destination)
                    }
                    fileBeingRenamed = nil
                }
            } message: {
                Text("Rename within the current project.")
            }
            .alert(
                "Project Error",
                isPresented: Binding(
                    get: { model.errorMessage != nil },
                    set: { presented in
                        if !presented {
                            model.clearError()
                        }
                    }
                )
            ) {
                Button("OK", role: .cancel) {
                    model.clearError()
                }
            } message: {
                Text(model.errorMessage ?? "")
            }
        }
    }

    private var fileStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(model.files, id: \.self) { path in
                    Button {
                        perform {
                            try model.selectFile(path)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: fileIcon(for: path))
                                .font(.caption)

                            Text(path.fileName)
                                .font(.caption.monospaced())
                                .lineLimit(1)

                            if model.dirtyFilePaths.contains(path) {
                                Circle()
                                    .frame(width: 6, height: 6)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                    }
                    .buttonStyle(.bordered)
                    .tint(model.activeFilePath == path ? .accentColor : .secondary)
                    .contextMenu {
                        Button("Rename", systemImage: "pencil") {
                            fileBeingRenamed = path
                            renameDestination = path.value
                        }
                        .disabled(path == model.entryFilePath)

                        Button("Delete", systemImage: "trash", role: .destructive) {
                            perform {
                                try model.deleteFile(at: path)
                            }
                        }
                        .disabled(path == model.entryFilePath)
                    }
                }

                Button {
                    newFilePath = ""
                    isCreatingFile = true
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Create file")
            }
        }
    }

    private var compilerStatus: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.shield.fill")
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 2) {
                Text("Project Workspace")
                    .font(.subheadline.weight(.semibold))
                Text("\(model.files.count) file(s) • Local provider pipeline")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("0.1.2")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func fileIcon(for path: WorkspacePath?) -> String {
        guard let path else { return "doc" }

        switch path.pathExtension.lowercased() {
        case "swift":
            return "swift"
        case "c", "cc", "cpp", "cxx", "m", "mm":
            return "chevron.left.forwardslash.chevron.right"
        case "json", "plist":
            return "curlybraces"
        case "md", "txt":
            return "doc.text"
        default:
            return "doc"
        }
    }

    private func perform(_ operation: () throws -> Void) {
        do {
            try operation()
        } catch {
            model.present(error: error)
        }
    }
}

#Preview {
    WorkspaceView()
}
