import Foundation

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
            uniqueKeysWithValues:
                initialTextFiles.map {
                    path,
                    text in
                    let expanded =
                        text.replacingOccurrences(
                            of: "{{PROJECT_NAME}}",
                            with:
                                projectDisplayName
                        )
                    return (
                        path,
                        Data(expanded.utf8)
                    )
                }
        )

        return (
            descriptor,
            files
        )
    }
}

enum BuiltInProjectTemplates {
    static let empty = ProjectTemplate(
        id: "empty",
        displayName: "Empty Project",
        summary:
            "Start with an empty multi-file workspace."
    )

    static let swiftConsole = ProjectTemplate(
        id: "swift-console",
        displayName: "Swift Console",
        summary:
            "A local Swift project with a runnable main.swift.",
        entryFilePath:
            try! WorkspacePath("main.swift"),
        initialTextFiles: [
            try! WorkspacePath("main.swift"):
                """
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

    static let swiftUIPreview = ProjectTemplate(
        id: "swiftui-preview",
        displayName: "SwiftUI Preview",
        summary:
            "A state-aware SwiftUI project for the signed App Preview runtime.",
        entryFilePath:
            try! WorkspacePath(
                "ContentView.swift"
            ),
        initialTextFiles: [
            try! WorkspacePath(
                "ContentView.swift"
            ):
                """
                import SwiftUI

                struct ContentView: View {
                    @State private var status = "Ready"
                    @State private var count = 0
                    @State private var name = "iSwift Code"
                    @State private var enabled = true

                    var body: some View {
                        NavigationStack {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack(alignment: .center, spacing: 12) {
                                    Image(systemName: "swift")
                                        .foregroundStyle(.orange)
                                        .font(.largeTitle)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("{{PROJECT_NAME}}")
                                            .font(.title)

                                        Text(status)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                TextField("Name", text: $name)

                                Toggle("Enabled", isOn: $enabled)

                                Text("Hello, \\(name)")
                                    .font(.headline)

                                Text("Count: \\(count)")
                                    .font(.headline)

                                HStack(spacing: 12) {
                                    Button("Add") {
                                        count += 1
                                    }

                                    Button("Toggle") {
                                        enabled.toggle()
                                    }

                                    Spacer()

                                    Text("0.1.3")
                                        .font(.caption)
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity)
                                .background(.blue)
                                .cornerRadius(14)

                                NavigationLink("Open Details") {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Preview Details")
                                            .font(.title2)

                                        Text("Hello, \(name)")
                                            .font(.headline)

                                        Text("Count: \(count)")
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(20)
                                    .navigationTitle("Details")
                                }
                            }
                            .padding(20)
                            .navigationTitle("{{PROJECT_NAME}}")
                        }
                    }
                }
                """
        ],
        descriptorAttributes: [
            "language": "swift",
            "projectKind": "app-preview",
            "previewProvider": "swiftui"
        ]
    )

    static let all: [ProjectTemplate] = [
        swiftUIPreview,
        swiftConsole,
        empty
    ]

    static func template(
        id: String
    ) -> ProjectTemplate? {
        all.first {
            $0.id == id
        }
    }
}
