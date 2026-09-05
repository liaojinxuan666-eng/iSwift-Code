import SwiftUI

struct ProjectBrowserView: View {
    @StateObject private var model: ProjectBrowserViewModel

    @State private var isCreatingProject = false
    @State private var newProjectName = ""
    @State private var selectedTemplateID =
        BuiltInProjectTemplates.swiftConsole.id

    @State private var openedSession: ProjectSessionViewModel?
    @State private var isShowingWorkspace = false
    @State private var projectPendingDeletion: ProjectDescriptor?

    init() {
        _model = StateObject(
            wrappedValue: ProjectBrowserViewModel()
        )
    }

    init(model: ProjectBrowserViewModel) {
        _model = StateObject(wrappedValue: model)
    }

    var body: some View {
        NavigationStack {
            Group {
                if model.projects.isEmpty {
                    emptyState
                } else {
                    projectList
                }
            }
            .navigationTitle("Projects")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        newProjectName = ""
                        selectedTemplateID =
                            BuiltInProjectTemplates.swiftConsole.id
                        isCreatingProject = true
                    } label: {
                        Label("New Project", systemImage: "plus")
                    }
                }
            }
            .navigationDestination(isPresented: $isShowingWorkspace) {
                if let openedSession {
                    WorkspaceView(model: openedSession)
                } else {
                    ContentUnavailableView(
                        "Project unavailable",
                        systemImage: "exclamationmark.triangle"
                    )
                }
            }
            .sheet(isPresented: $isCreatingProject) {
                NewProjectSheet(
                    projectName: $newProjectName,
                    selectedTemplateID: $selectedTemplateID,
                    templates: model.templates
                ) {
                    createProject()
                }
            }
            .alert(
                "Delete Project?",
                isPresented: Binding(
                    get: { projectPendingDeletion != nil },
                    set: { presented in
                        if !presented {
                            projectPendingDeletion = nil
                        }
                    }
                ),
                presenting: projectPendingDeletion
            ) { project in
                Button("Cancel", role: .cancel) {
                    projectPendingDeletion = nil
                }

                Button("Delete", role: .destructive) {
                    do {
                        try model.deleteProject(project)
                    } catch {
                        model.present(error: error)
                    }
                    projectPendingDeletion = nil
                }
            } message: { project in
                Text(
                    "This permanently deletes “\(project.displayName)” and its project files."
                )
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
            .onAppear {
                model.refresh()
            }
        }
    }

    private var projectList: some View {
        List {
            Section {
                ForEach(model.projects, id: \.identifier) { project in
                    Button {
                        open(project)
                    } label: {
                        ProjectRow(project: project)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(
                            "Delete Project",
                            systemImage: "trash",
                            role: .destructive
                        ) {
                            projectPendingDeletion = project
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            projectPendingDeletion = project
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            } header: {
                Text("\(model.projects.count) project(s)")
            } footer: {
                Text(
                    "Projects are stored locally in iSwift Code's Application Support directory."
                )
            }
        }
        .listStyle(.insetGrouped)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Projects", systemImage: "folder")
        } description: {
            Text("Create a project to start coding.")
        } actions: {
            Button("New Project") {
                isCreatingProject = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func open(_ project: ProjectDescriptor) {
        do {
            openedSession = try model.openSession(for: project)
            isShowingWorkspace = true
        } catch {
            model.present(error: error)
        }
    }

    private func createProject() {
        do {
            let descriptor = try model.createProject(
                displayName: newProjectName,
                templateID: selectedTemplateID
            )

            isCreatingProject = false
            newProjectName = ""

            openedSession = try model.openSession(for: descriptor)
            isShowingWorkspace = true
        } catch {
            model.present(error: error)
        }
    }
}

private struct ProjectRow: View {
    let project: ProjectDescriptor

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: iconName)
                .font(.title2)
                .frame(width: 38, height: 38)
                .background(.thinMaterial)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 10,
                        style: .continuous
                    )
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(project.displayName)
                    .font(.headline)
                    .foregroundStyle(.primary)

                if let entry = project.entryFilePath {
                    Text("Entry: \(entry.value)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text("No entry file")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let template = project.attributes["template"] {
                    Text(template)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
    }

    private var iconName: String {
        switch project.attributes["language"] {
        case "swift":
            return "swift"
        case "c", "cpp", "objective-c", "objective-cpp":
            return "chevron.left.forwardslash.chevron.right"
        default:
            return "folder"
        }
    }
}

private struct NewProjectSheet: View {
    @Binding var projectName: String
    @Binding var selectedTemplateID: String

    let templates: [ProjectTemplate]
    let create: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Project") {
                    TextField("Project Name", text: $projectName)
                        .textInputAutocapitalization(.words)
                }

                Section("Template") {
                    Picker(
                        "Template",
                        selection: $selectedTemplateID
                    ) {
                        ForEach(templates) { template in
                            Text(template.displayName)
                                .tag(template.id)
                        }
                    }
                    .pickerStyle(.inline)

                    if let selected = templates.first(
                        where: { $0.id == selectedTemplateID }
                    ) {
                        Text(selected.summary)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        create()
                    }
                    .disabled(
                        projectName
                            .trimmingCharacters(
                                in: .whitespacesAndNewlines
                            )
                            .isEmpty
                    )
                }
            }
        }
    }
}

#Preview {
    ProjectBrowserView()
}
