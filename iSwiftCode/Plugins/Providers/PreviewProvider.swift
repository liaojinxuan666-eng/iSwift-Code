import Foundation

enum PreviewPlatform: String, Codable, CaseIterable, Hashable, Sendable {
    case iOS
}

enum PreviewDeviceFamily: String, Codable, CaseIterable, Hashable, Sendable {
    case phone
    case pad
}

struct PreviewSourceFile: Equatable, Sendable {
    let path: String
    let contents: String
}

struct PreviewRequest: Equatable, Sendable {
    let files: [PreviewSourceFile]
    let entryFilePath: String?
    let platform: PreviewPlatform
    let deviceFamily: PreviewDeviceFamily

    init(
        files: [PreviewSourceFile],
        entryFilePath: String? = nil,
        platform: PreviewPlatform = .iOS,
        deviceFamily: PreviewDeviceFamily = .phone
    ) {
        self.files = files
        self.entryFilePath = entryFilePath
        self.platform = platform
        self.deviceFamily = deviceFamily
    }
}

enum PreviewDiagnosticSeverity: String, Codable, Sendable {
    case warning
    case error
}

struct PreviewDiagnostic: Equatable, Sendable {
    let severity: PreviewDiagnosticSeverity
    let message: String
    let filePath: String?
}

struct PreviewProviderResult: Sendable {
    let document: PreviewDocument?
    let diagnostics: [PreviewDiagnostic]

    init(
        document: PreviewDocument? = nil,
        diagnostics: [PreviewDiagnostic] = []
    ) {
        self.document = document
        self.diagnostics = diagnostics
    }

    var succeeded: Bool {
        document != nil && !diagnostics.contains(where: { $0.severity == .error })
    }
}

enum PreviewProviderError: Error, Equatable, Sendable {
    case invalidRequest(String)
    case unsupportedPlatform(PreviewPlatform)
}

extension PreviewProviderError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidRequest(let message):
            return message
        case .unsupportedPlatform(let platform):
            return "Preview provider does not support platform '\(platform.rawValue)'."
        }
    }
}

protocol PreviewProvider: ISwiftPlugin {
    var providerName: String { get }
    var supportedPlatforms: Set<PreviewPlatform> { get }

    func makePreview(_ request: PreviewRequest) throws -> PreviewProviderResult
}
