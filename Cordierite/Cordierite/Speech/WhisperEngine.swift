import AVFoundation
import Foundation
import WhisperCppBridge

@MainActor
final class WhisperEngine: SpeechRecognitionEngine {
    private var whisperConfiguration: WhisperConfiguration
    private let pcmBuffer = WhisperPCMBuffer.Accumulator()
    private let modelStore = WhisperModelStore.shared
    private var runner: WhisperCppRunner?
    private var loadedModelID: String?
    private var isSessionActive = false
    private(set) var downloadProgress: Progress?

    var loadingStatusMessage: String {
        "Downloading \(selectedModel.shortLabel)…"
    }

    var selectedModel: WhisperModelOption {
        WhisperModelOption.resolved(from: whisperConfiguration.model)
    }

    var isReady: Bool {
        runner != nil && loadedModelID == whisperConfiguration.model
    }

    init(whisperConfiguration: WhisperConfiguration) {
        self.whisperConfiguration = WhisperConfiguration(
            model: WhisperModelCatalog.normalizedModelID(whisperConfiguration.model),
            language: whisperConfiguration.language
        )
    }

    func updateConfiguration(_ configuration: WhisperConfiguration) {
        let normalized = WhisperConfiguration(
            model: WhisperModelCatalog.normalizedModelID(configuration.model),
            language: configuration.language
        )

        if normalized.model != whisperConfiguration.model {
            runner = nil
            loadedModelID = nil
        }

        whisperConfiguration = normalized
    }

    func isSelectedModelDownloaded() async -> Bool {
        (try? await modelStore.isDownloaded(modelID: whisperConfiguration.model)) ?? false
    }

    func prepare(language: RecognitionLanguageOption) async throws {
        _ = language

        guard try await modelStore.isDownloaded(modelID: whisperConfiguration.model) else {
            runner = nil
            loadedModelID = nil
            return
        }

        try await loadRunnerIfNeeded()
    }

    func downloadSelectedModel() async throws {
        let modelID = whisperConfiguration.model
        let progress = Progress(totalUnitCount: 0)
        progress.kind = .file
        downloadProgress = progress

        defer {
            downloadProgress = nil
        }

        do {
            let modelPath = try await modelStore.download(modelID: modelID)
            runner = nil
            loadedModelID = nil
            try await loadRunner(modelPath: modelPath.path, modelID: modelID)
        } catch is WhisperModelStoreError {
            throw SpeechEngineError.whisperModelDownloadFailed
        } catch let error as WhisperCppBridgeError {
            throw mapBridgeError(error)
        } catch let error as SpeechEngineError {
            throw error
        } catch {
            throw SpeechEngineError.whisperUnavailable
        }
    }

    func start(language: RecognitionLanguageOption) async throws -> AsyncThrowingStream<RecognitionEvent, Error> {
        _ = language
        pcmBuffer.reset()
        isSessionActive = true

        return AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }

    func processAudioBuffer(_ buffer: AVAudioPCMBuffer) throws {
        guard isSessionActive else {
            throw SpeechEngineError.sessionNotActive
        }

        try pcmBuffer.append(buffer)
    }

    func stop() async throws -> String {
        guard isSessionActive else {
            throw SpeechEngineError.sessionNotActive
        }

        isSessionActive = false

        let samples = pcmBuffer.snapshot()
        guard !samples.isEmpty else {
            throw SpeechEngineError.transcriptionFailed
        }

        guard let runner else {
            throw SpeechEngineError.whisperModelNotReady
        }

        let language = whisperConfiguration.language.whisperCode

        do {
            let text = try await Task.detached(priority: .userInitiated) {
                try await runner.transcribe(samples: samples, language: language)
            }.value

            guard !text.isEmpty else {
                throw SpeechEngineError.transcriptionFailed
            }

            return text
        } catch let error as WhisperCppBridgeError {
            throw mapBridgeError(error)
        } catch let error as SpeechEngineError {
            throw error
        } catch {
            throw SpeechEngineError.transcriptionFailed
        }
    }

    func cancelSession() async {
        isSessionActive = false
        pcmBuffer.reset()
    }

    func shutdown() async {
        await cancelSession()
        runner = nil
        loadedModelID = nil
    }

    func unloadLoadedModel() {
        runner = nil
        loadedModelID = nil
    }

    private func loadRunnerIfNeeded() async throws {
        let modelID = whisperConfiguration.model
        if loadedModelID == modelID, runner != nil {
            return
        }

        let modelPath = try await modelStore.localURL(for: modelID)
        try await loadRunner(modelPath: modelPath.path, modelID: modelID)
    }

    private func loadRunner(modelPath: String, modelID: String) async throws {
        runner = nil
        loadedModelID = nil

        let whisperRunner = try await Task.detached(priority: .userInitiated) {
            try WhisperCppRunner(modelPath: modelPath)
        }.value

        try await Task.detached(priority: .userInitiated) {
            try await whisperRunner.warmup()
        }.value

        runner = whisperRunner
        loadedModelID = modelID
    }

    private func mapBridgeError(_ error: WhisperCppBridgeError) -> SpeechEngineError {
        switch error {
        case .failedToLoadModel:
            .whisperUnavailable
        case .transcriptionFailed:
            .transcriptionFailed
        }
    }
}
