import Foundation

enum AITask: String, Codable, CaseIterable, Hashable, Sendable {
    case chat
    case explainDiagnostics
    case generateCode
    case editWorkspace
    case reviewWorkspace
}

enum AIMessageRole: String, Codable, Hashable, Sendable {
    case system
    case user
    case assistant
}

struct AIMessage: Codable, Equatable, Hashable, Sendable {
    let role: AIMessageRole
    let content: String
}

struct AIWorkspaceFile: Codable, Equatable, Hashable, Sendable {
    let path: String
    let contents: String
}

enum AIFileEditOperation: String, Codable, Hashable, Sendable {
    case create
    case replace
    case delete
    case rename
}

struct AIFileEdit: Codable, Equatable, Hashable, Sendable {
    let operation: AIFileEditOperation
    let path: String
    let newPath: String?
    let contents: String?

    init(
        operation: AIFileEditOperation,
        path: String,
        newPath: String? = nil,
        contents: String? = nil
    ) {
        self.operation = operation
        self.path = path
        self.newPath = newPath
        self.contents = contents
    }
}

struct AIProviderRequest: Sendable {
    let task: AITask
    let messages: [AIMessage]
    let workspaceFiles: [AIWorkspaceFile]
    let selectedText: String?
    let diagnostics: [CompilerDiagnostic]

    init(
        task: AITask,
        messages: [AIMessage] = [],
        workspaceFiles: [AIWorkspaceFile] = [],
        selectedText: String? = nil,
        diagnostics: [CompilerDiagnostic] = []
    ) {
        self.task = task
        self.messages = messages
        self.workspaceFiles = workspaceFiles
        self.selectedText = selectedText
        self.diagnostics = diagnostics
    }
}

struct AIProviderResponse: Sendable {
    let message: String
    let edits: [AIFileEdit]

    init(message: String, edits: [AIFileEdit] = []) {
        self.message = message
        self.edits = edits
    }
}

enum AIProviderError: Error, Equatable, Sendable {
    case unsupportedTask(AITask)
    case invalidRequest(String)
    case providerUnavailable(String)
}

extension AIProviderError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .unsupportedTask(let task):
            return "AI provider does not support task '\(task.rawValue)'."
        case .invalidRequest(let message):
            return message
        case .providerUnavailable(let message):
            return message
        }
    }
}

protocol AIProvider: ISwiftPlugin {
    var providerName: String { get }
    var supportedTasks: Set<AITask> { get }

    func perform(_ request: AIProviderRequest) async throws -> AIProviderResponse
}
