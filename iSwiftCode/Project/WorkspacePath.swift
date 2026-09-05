import Foundation

enum WorkspacePathError: Error, Equatable, Sendable {
    case empty
    case absolutePath
    case invalidSeparator
    case invalidComponent(String)
    case containsNullByte
}

extension WorkspacePathError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .empty:
            return "Workspace path cannot be empty."
        case .absolutePath:
            return "Workspace path must be relative."
        case .invalidSeparator:
            return "Workspace paths must use '/' separators."
        case .invalidComponent(let component):
            return "Workspace path contains an invalid component: '\(component)'."
        case .containsNullByte:
            return "Workspace path cannot contain a null byte."
        }
    }
}

/// Canonical relative path used everywhere inside an iSwift Code project.
///
/// `WorkspacePath` deliberately rejects absolute paths, `..`, `.`, backslashes,
/// empty components, and null bytes. Project code and plugins therefore exchange
/// project-relative paths rather than raw filesystem paths.
struct WorkspacePath: Hashable, Comparable, Sendable {
    let value: String

    init(_ rawValue: String) throws {
        guard !rawValue.isEmpty else {
            throw WorkspacePathError.empty
        }
        guard !rawValue.contains("\0") else {
            throw WorkspacePathError.containsNullByte
        }
        guard !rawValue.hasPrefix("/") else {
            throw WorkspacePathError.absolutePath
        }
        guard !rawValue.contains("\\") else {
            throw WorkspacePathError.invalidSeparator
        }

        let components = rawValue.split(separator: "/", omittingEmptySubsequences: false)
        guard !components.isEmpty else {
            throw WorkspacePathError.empty
        }

        for component in components {
            let string = String(component)
            guard !string.isEmpty, string != ".", string != ".." else {
                throw WorkspacePathError.invalidComponent(string)
            }
        }

        value = components.map(String.init).joined(separator: "/")
    }

    var fileName: String {
        value.split(separator: "/").last.map(String.init) ?? value
    }

    var pathExtension: String {
        let name = fileName
        guard let dot = name.lastIndex(of: "."), dot != name.startIndex else {
            return ""
        }
        return String(name[name.index(after: dot)...])
    }

    static func < (lhs: WorkspacePath, rhs: WorkspacePath) -> Bool {
        lhs.value < rhs.value
    }
}

extension WorkspacePath: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        do {
            try self.init(rawValue)
        } catch {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid workspace path '\(rawValue)': \(error.localizedDescription)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}
