import Foundation

enum ProjectProviderBridgeError: Error, Equatable, Sendable {
    case noSourceFiles
    case sourceFileIsNotUTF8(WorkspacePath)
    case entryFileIsNotSource(WorkspacePath)
}

extension ProjectProviderBridgeError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .noSourceFiles:
            return "Project does not contain any recognized source files."
        case .sourceFileIsNotUTF8(let path):
            return "Source file '\(path.value)' is not valid UTF-8 text."
        case .entryFileIsNotSource(let path):
            return "Project entry file '\(path.value)' is not a recognized compiler source file."
        }
    }
}

/// Language classification shared by workspace/compiler integration.
///
/// Classification is extension-based and provider-neutral. A provider remains
/// free to reject a language it does not support.
enum ProjectSourceLanguageResolver {
    static func language(for path: WorkspacePath) -> CompilerLanguage? {
        switch path.pathExtension.lowercased() {
        case "swift":
            return .swift
        case "c":
            return .c
        case "cc", "cpp", "cxx":
            return .cpp
        case "m":
            return .objectiveC
        case "mm":
            return .objectiveCpp
        default:
            return nil
        }
    }
}

/// Converts the generic project snapshot into typed provider requests.
///
/// This layer contains no Clang-, Swift-, AI-service-, or app-specific branches.
/// It only translates shared workspace data into existing provider contracts.
enum ProjectProviderBridge {
    static func compilerRequest(
        from snapshot: ProjectWorkspaceSnapshot,
        operation: CompilerOperation,
        arguments: [String] = []
    ) throws -> CompilerRequest {
        var sourceFiles: [CompilerSourceFile] = []

        for file in snapshot.files {
            guard let language = ProjectSourceLanguageResolver.language(for: file.path) else {
                continue
            }
            guard let contents = file.text else {
                throw ProjectProviderBridgeError.sourceFileIsNotUTF8(file.path)
            }

            sourceFiles.append(
                CompilerSourceFile(
                    path: file.path.value,
                    contents: contents,
                    language: language
                )
            )
        }

        guard !sourceFiles.isEmpty else {
            throw ProjectProviderBridgeError.noSourceFiles
        }

        let entryPath = snapshot.descriptor.entryFilePath?.value
        if let configuredEntry = snapshot.descriptor.entryFilePath,
           !sourceFiles.contains(where: { $0.path == configuredEntry.value }) {
            throw ProjectProviderBridgeError.entryFileIsNotSource(configuredEntry)
        }

        return CompilerRequest(
            operation: operation,
            files: sourceFiles,
            entryFilePath: entryPath,
            arguments: arguments
        )
    }

    static func aiWorkspaceFiles(
        from snapshot: ProjectWorkspaceSnapshot
    ) -> [AIWorkspaceFile] {
        snapshot.files.compactMap { file in
            guard let contents = file.text else {
                return nil
            }
            return AIWorkspaceFile(
                path: file.path.value,
                contents: contents
            )
        }
    }

    static func aiRequest(
        from snapshot: ProjectWorkspaceSnapshot,
        task: AITask,
        messages: [AIMessage] = [],
        selectedText: String? = nil,
        diagnostics: [CompilerDiagnostic] = []
    ) -> AIProviderRequest {
        AIProviderRequest(
            task: task,
            messages: messages,
            workspaceFiles: aiWorkspaceFiles(from: snapshot),
            selectedText: selectedText,
            diagnostics: diagnostics
        )
    }
}
