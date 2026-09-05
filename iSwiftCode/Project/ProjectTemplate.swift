import Foundation

/// Portable project creation template.
///
/// A template describes initial project metadata and files only. It does not
/// own compiler/provider selection and is not tied to a specific editor UI.
struct ProjectTemplate: Identifiable, Sendable {
    let id: String
    let displayName: String
    let summary: String
    let entryFilePath: WorkspacePath?
    let initialTextFiles: [WorkspacePath: String]
    let descriptorAttributes: [String: String]

    init(
        id: String,
        displayName: String,
        summary: String,
        entryFilePath: WorkspacePath? = nil,
        initialTextFiles: [WorkspacePath: String] = [:],
        descriptorAttributes: [String: String] = [:]
    ) {
        self.id = id
        self.displayName = displayName
        self.summary = summary
        self.entryFilePath = entryFilePath
        self.initialTextFiles = initialTextFiles
        self.descriptorAttributes = descriptorAttributes
    }

    func instantiate(
        projectIdentifier: String,
        projectDisplayName: String
    ) -> (
        descriptor: ProjectDescriptor,
        initialFiles: [WorkspacePath: Data]
    ) {
        let descriptor = ProjectDescriptor(
            identifier: projectIdentifier,
            displayName: projectDisplayName,
            entryFilePath: entryFilePath,
            attributes: descriptorAttributes.merging(
                ["template": id],
                uniquingKeysWith: { _, new in new }
            )
        )

        let files = Dictionary(
            uniqueKeysWithValues: initialTextFiles.map { path, text in
                let expanded = text.replacingOccurrences(
                    of: "{{PROJECT_NAME}}",
                    with: projectDisplayName
                )
                return (path, Data(expanded.utf8))
            }
        )

        return (descriptor, files)
    }
}

enum BuiltInProjectTemplates {
    static let empty = ProjectTemplate(
        id: "empty",
        displayName: "Empty Project",
        summary: "Start with an empty multi-file workspace."
    )

    static let swiftConsole = ProjectTemplate(
        id: "swift-console",
        displayName: "Swift Console",
        summary: "A local Swift project with a runnable main.swift.",
        entryFilePath: try! WorkspacePath("main.swift"),
        initialTextFiles: [
            try! WorkspacePath("main.swift"): """
            let projectName = "{{PROJECT_NAME}}"
            print(projectName)
            print("Hello from iSwift Code")
            """
        ],
        descriptorAttributes: [
            "language": "swift",
            "projectKind": "console"
        ]
    )

    static let all: [ProjectTemplate] = [
        swiftConsole,
        empty
    ]

    static func template(id: String) -> ProjectTemplate? {
        all.first { $0.id == id }
    }
}
