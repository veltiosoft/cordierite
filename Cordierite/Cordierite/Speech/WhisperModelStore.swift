import Foundation

enum WhisperModelStoreError: LocalizedError, Sendable {
    case unknownModel(String)
    case downloadFailed

    var errorDescription: String? {
        switch self {
        case .unknownModel(let modelID):
            "Unknown Whisper model: \(modelID)."
        case .downloadFailed:
            "Could not download the Whisper model."
        }
    }
}

enum WhisperModelOption: String, Codable, CaseIterable, Identifiable, Sendable {
    case largeV3TurboQ5_0 = "large-v3-turbo-q5_0"
    case largeV3TurboQ8_0 = "large-v3-turbo-q8_0"
    case largeV3Turbo = "large-v3-turbo"
    case base = "base"

    nonisolated static let `default` = largeV3TurboQ5_0

    nonisolated var id: String { rawValue }

    nonisolated var menuLabel: String {
        switch self {
        case .largeV3TurboQ5_0:
            "Large v3 Turbo Q5_0 (~500 MB)"
        case .largeV3TurboQ8_0:
            "Large v3 Turbo Q8_0 (~800 MB)"
        case .largeV3Turbo:
            "Large v3 Turbo (~1.5 GB)"
        case .base:
            "Base (~140 MB)"
        }
    }

    nonisolated var shortLabel: String {
        switch self {
        case .largeV3TurboQ5_0:
            "Whisper Large v3 Turbo Q5_0"
        case .largeV3TurboQ8_0:
            "Whisper Large v3 Turbo Q8_0"
        case .largeV3Turbo:
            "Whisper Large v3 Turbo"
        case .base:
            "Whisper Base"
        }
    }

    nonisolated var engineSelectionLabel: String {
        switch self {
        case .largeV3TurboQ5_0:
            "Large v3 Turbo Q5_0"
        case .largeV3TurboQ8_0:
            "Large v3 Turbo Q8_0"
        case .largeV3Turbo:
            "Large v3 Turbo"
        case .base:
            "Base"
        }
    }

    nonisolated var filename: String {
        switch self {
        case .largeV3TurboQ5_0:
            "ggml-large-v3-turbo-q5_0.bin"
        case .largeV3TurboQ8_0:
            "ggml-large-v3-turbo-q8_0.bin"
        case .largeV3Turbo:
            "ggml-large-v3-turbo.bin"
        case .base:
            "ggml-base.bin"
        }
    }

    nonisolated var approximateDownloadSize: String {
        switch self {
        case .largeV3TurboQ5_0:
            "~500 MB"
        case .largeV3TurboQ8_0:
            "~800 MB"
        case .largeV3Turbo:
            "~1.5 GB"
        case .base:
            "~140 MB"
        }
    }

    nonisolated var sourceRepository: String {
        "ggerganov/whisper.cpp"
    }

    nonisolated var downloadURL: URL {
        URL(string: "https://huggingface.co/\(sourceRepository)/resolve/main/\(filename)?download=true")!
    }

    nonisolated static func resolved(from rawValue: String) -> WhisperModelOption {
        WhisperModelOption(rawValue: WhisperModelCatalog.normalizedModelID(rawValue)) ?? .default
    }
}

enum WhisperModelCatalog: Sendable {
    nonisolated static let defaultModelID = WhisperModelOption.default.rawValue

    nonisolated static func normalizedModelID(_ rawValue: String) -> String {
        if rawValue.hasPrefix("mlx-community/") || rawValue.contains("/") {
            return defaultModelID
        }
        if WhisperModelOption(rawValue: rawValue) != nil {
            return rawValue
        }
        return defaultModelID
    }

    nonisolated static func filename(for modelID: String) throws -> String {
        guard let model = WhisperModelOption(rawValue: normalizedModelID(modelID)) else {
            throw WhisperModelStoreError.unknownModel(modelID)
        }
        return model.filename
    }

    nonisolated static func remoteURL(for modelID: String) throws -> URL {
        guard let model = WhisperModelOption(rawValue: normalizedModelID(modelID)) else {
            throw WhisperModelStoreError.unknownModel(modelID)
        }
        return model.downloadURL
    }

    nonisolated static var defaultDirectoryURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport
            .appendingPathComponent("Cordierite", isDirectory: true)
            .appendingPathComponent("whisper-models", isDirectory: true)
    }
}

actor WhisperModelStore {
    static let shared = WhisperModelStore()

    private let directory: URL

    init(directory: URL = WhisperModelCatalog.defaultDirectoryURL) {
        self.directory = directory
    }

    func localURL(for modelID: String) throws -> URL {
        directory.appendingPathComponent(try WhisperModelCatalog.filename(for: modelID))
    }

    func isDownloaded(modelID: String) throws -> Bool {
        let url = try localURL(for: modelID)
        return FileManager.default.fileExists(atPath: url.path)
    }

    func download(modelID: String) async throws -> URL {
        let destination = try localURL(for: modelID)
        if FileManager.default.fileExists(atPath: destination.path) {
            return destination
        }

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let remoteURL = try WhisperModelCatalog.remoteURL(for: modelID)
        let (temporaryURL, response) = try await URLSession.shared.download(from: remoteURL)
        defer {
            try? FileManager.default.removeItem(at: temporaryURL)
        }

        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw WhisperModelStoreError.downloadFailed
        }

        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: destination)

        return destination
    }
}
