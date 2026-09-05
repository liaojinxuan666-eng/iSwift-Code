import Foundation

enum ProjectDescriptorError: Error, Equatable, Sendable {
    case invalidIdentifier
    case invalidDisplayName
    case invalidSchemaVersion
}

extension ProjectDescriptorError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidIdentifier:
            return "Project identifier cannot be empty and may contain only letters, numbers, '.', '-', and '_'."
        case .invalidDisplayName:
            return "Project display name cannot be empty."
        case .invalidSchemaVersion:
            return "Project schema version must be greater than zero."
        }
    }
}

/// Portable project metadata.
///
/// The descriptor intentionally does not encode Swift-, Clang-, app-, or
/// simulator-specific settings. Toolchain-specific configuration belongs in
/// providers/build configuration layered on top of the workspace.
struct ProjectDescriptor: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    let identifier: String
    let displayName: String
    let schemaVersion: Int
    let entryFilePath: WorkspacePath?
    let attributes: [String: String]

    init(
        identifier: String,
        displayName: String,
        schemaVersion: Int = ProjectDescriptor.currentSchemaVersion,
        entryFilePath: WorkspacePath? = nil,
        attributes: [String: String] = [:]
    ) {
        self.identifier = identifier
        self.displayName = displayName
        self.schemaVersion = schemaVersion
        self.entryFilePath = entryFilePath
        self.attributes = attributes
    }

    func validate() throws {
        guard Self.isValidIdentifier(identifier) else {
            throw ProjectDescriptorError.invalidIdentifier
        }
        guard !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ProjectDescriptorError.invalidDisplayName
        }
        guard schemaVersion > 0 else {
            throw ProjectDescriptorError.invalidSchemaVersion
        }
    }

    private static func isValidIdentifier(_ identifier: String) -> Bool {
        guard !identifier.isEmpty else { return false }

        for character in identifier {
            guard character.isLetter ||
                    character.isNumber ||
                    character == "." ||
                    character == "-" ||
                    character == "_" else {
                return false
            }
        }
        return true
    }
}
