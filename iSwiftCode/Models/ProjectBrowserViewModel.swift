import Foundation
import Combine

enum ProjectBrowserError: Error, Equatable, Sendable {
    case persistentStoreUnavailable
    case emptyProjectName
    case templateNotFound(String)
}

extension ProjectBrowserError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .persistentStoreUnavailable:
            return "Persistent project storage is unavailable."
        case .emptyProjectName:
            return "Project name cannot be empty."
        case .templateNotFound(let identifier):
            return "Project template '\(identifier)' was not found."
        }
    }
}

/// Project catalog/session coordinator.
///
/// The browser works with ProjectStore and ProjectTemplate contracts. Compiler
/// selection is injected through a factory so the catalog itself is not tied to
/// SandboxSwiftCompilerProvider, Clang, or any future provider.
@MainActor
final class ProjectBrowserViewModel: ObservableObject {
    @Published private(set) var projects: [ProjectDescriptor] = []
    @Published var errorMessage: String?

    let templates: [ProjectTemplate]

    private let store: ProjectStore?
    private let compilerFactory: @MainActor () -> any CompilerProvider

    init(
        store: ProjectStore? = nil,
        templates: [ProjectTemplate] = BuiltInProjectTemplates.all,
        seedDefaultProject: Bool = true,
        compilerFactory: @escaping @MainActor () -> any CompilerProvider = {
            SandboxSwiftCompilerProvider()
        }
    ) {
        self.templates = templates
        self.compilerFactory = compilerFactory

        let resolvedStore: ProjectStore?
        if let store {
            resolvedStore = store
        } else {
            resolvedStore = try? ProjectStore.applicationSupport()
        }
        self.store = resolvedStore

        guard let resolvedStore else {
            errorMessage = ProjectBrowserError
                .persistentStoreUnavailable
                .localizedDescription
            return
        }

        do {
            var descriptors = try resolvedStore.listProjects()

            if descriptors.isEmpty, seedDefaultProject {
                let template = BuiltInProjectTemplates.swiftConsole
                let project = template.instantiate(
                    projectIdentifier: "iswift.scratch",
                    projectDisplayName: "Scratch Project"
                )

                _ = try resolvedStore.createProject(
                    descriptor: project.descriptor,
                    initialFiles: project.initialFiles
                )

                descriptors = try resolvedStore.listProjects()
            }

            projects = descriptors
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refresh() {
        guard let store else {
            errorMessage = ProjectBrowserError
                .persistentStoreUnavailable
                .localizedDescription
            return
        }

        do {
            projects = try store.listProjects()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func createProject(
        displayName rawDisplayName: String,
        templateID: String
    ) throws -> ProjectDescriptor {
        guard let store else {
            throw ProjectBrowserError.persistentStoreUnavailable
        }

        let displayName = rawDisplayName
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !displayName.isEmpty else {
            throw ProjectBrowserError.emptyProjectName
        }

        guard let template = templates.first(where: { $0.id == templateID }) else {
            throw ProjectBrowserError.templateNotFound(templateID)
        }

        let identifier = try nextAvailableIdentifier(
            displayName: displayName,
            store: store
        )

        let project = template.instantiate(
            projectIdentifier: identifier,
            projectDisplayName: displayName
        )

        _ = try store.createProject(
            descriptor: project.descriptor,
            initialFiles: project.initialFiles
        )

        projects = try store.listProjects()
        return project.descriptor
    }

    func openSession(
        for descriptor: ProjectDescriptor
    ) throws -> ProjectSessionViewModel {
        guard let store else {
            throw ProjectBrowserError.persistentStoreUnavailable
        }

        let workspace = try store.openProject(
            identifier: descriptor.identifier
        )

        return try ProjectSessionViewModel(
            compiler: compilerFactory(),
            workspace: workspace,
            preferredActiveFile: workspace.descriptor.entryFilePath,
            projectStore: store
        )
    }

    func deleteProject(_ descriptor: ProjectDescriptor) throws {
        guard let store else {
            throw ProjectBrowserError.persistentStoreUnavailable
        }

        try store.deleteProject(identifier: descriptor.identifier)
        projects = try store.listProjects()
    }

    func present(error: Error) {
        errorMessage = error.localizedDescription
    }

    func clearError() {
        errorMessage = nil
    }

    private func nextAvailableIdentifier(
        displayName: String,
        store: ProjectStore
    ) throws -> String {
        let slug = Self.slug(displayName)
        let base = "project.\(slug)"

        if !(try store.projectExists(identifier: base)) {
            return base
        }

        var suffix = 2
        while try store.projectExists(identifier: "\(base).\(suffix)") {
            suffix += 1
        }

        return "\(base).\(suffix)"
    }

    private static func slug(_ displayName: String) -> String {
        var result = ""
        var previousWasSeparator = false

        for character in displayName.lowercased() {
            if character.isLetter || character.isNumber {
                result.append(character)
                previousWasSeparator = false
            } else if !previousWasSeparator, !result.isEmpty {
                result.append("-")
                previousWasSeparator = true
            }
        }

        while result.last == "-" {
            result.removeLast()
        }

        return result.isEmpty ? "project" : result
    }
}
