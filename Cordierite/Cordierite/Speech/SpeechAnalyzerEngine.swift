import AVFoundation
import Foundation
import Speech

@MainActor
final class SpeechAnalyzerEngine: SpeechRecognitionEngine {
    private(set) var downloadProgress: Progress?

    private var transcriber: SpeechTranscriber?
    private var analyzer: SpeechAnalyzer?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var bufferConverter: AudioBufferConverter?
    private var resultsTask: Task<Void, Error>?
    private var eventContinuation: AsyncThrowingStream<RecognitionEvent, Error>.Continuation?
    private let transcriptBuffer = TranscriptBuffer()
    private var preparedLanguage: RecognitionLanguageOption?
    private var isSessionActive = false

    func prepare(language: RecognitionLanguageOption) async throws {
        guard let locale = await RecognitionLanguageResolver.resolvedLocale(for: language) else {
            throw SpeechEngineError.localeNotSupported
        }

        let transcriber = try await makeTranscriber(locale: locale)
        guard SpeechTranscriber.isAvailable else {
            throw SpeechEngineError.transcriberUnavailable
        }

        try await installAssetsIfNeeded(for: transcriber)
        preparedLanguage = language
    }

    func start(language: RecognitionLanguageOption) async throws -> AsyncThrowingStream<RecognitionEvent, Error> {
        if preparedLanguage != language {
            try await prepare(language: language)
        }

        guard let locale = await RecognitionLanguageResolver.resolvedLocale(for: language) else {
            throw SpeechEngineError.localeNotSupported
        }

        transcriptBuffer.reset()
        cleanupSession()

        let transcriber = try await makeTranscriber(locale: locale)
        guard SpeechTranscriber.isAvailable else {
            throw SpeechEngineError.transcriberUnavailable
        }

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        guard let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
            throw SpeechEngineError.analyzerNotConfigured
        }

        let (inputSequence, inputContinuation) = AsyncStream.makeStream(of: AnalyzerInput.self)
        try await analyzer.prepareToAnalyze(in: analyzerFormat)
        try await analyzer.start(inputSequence: inputSequence)

        self.transcriber = transcriber
        self.analyzer = analyzer
        self.inputContinuation = inputContinuation
        self.bufferConverter = AudioBufferConverter(targetFormat: analyzerFormat)
        self.isSessionActive = true

        let stream = AsyncThrowingStream<RecognitionEvent, Error> { continuation in
            self.eventContinuation = continuation
        }

        resultsTask = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                for try await result in transcriber.results {
                    let text = String(result.text.characters)
                    let event: RecognitionEvent = result.isFinal ? .final(text) : .partial(text)
                    transcriptBuffer.apply(event: event)
                    eventContinuation?.yield(event)
                }
                eventContinuation?.finish()
            } catch {
                eventContinuation?.finish(throwing: error)
                throw error
            }
        }

        return stream
    }

    func processAudioBuffer(_ buffer: AVAudioPCMBuffer) throws {
        guard isSessionActive,
              let bufferConverter,
              let inputContinuation else {
            throw SpeechEngineError.sessionNotActive
        }

        let converted = try bufferConverter.convertBuffer(buffer)
        inputContinuation.yield(AnalyzerInput(buffer: converted))
    }

    func stop() async throws -> String {
        guard isSessionActive else {
            throw SpeechEngineError.sessionNotActive
        }

        isSessionActive = false
        inputContinuation?.finish()
        inputContinuation = nil

        do {
            try await analyzer?.finalizeAndFinishThroughEndOfInput()
        } catch {
            cleanupSession()
            throw SpeechEngineError.transcriptionFailed
        }

        do {
            try await resultsTask?.value
        } catch {
            cleanupSession()
            throw SpeechEngineError.transcriptionFailed
        }

        let text = transcriptBuffer.finalizedText.trimmingCharacters(in: .whitespacesAndNewlines)
        cleanupSession()

        guard !text.isEmpty else {
            throw SpeechEngineError.transcriptionFailed
        }

        return text
    }

    func cancelSession() async {
        guard isSessionActive else {
            cleanupSession()
            return
        }

        isSessionActive = false
        inputContinuation?.finish()
        inputContinuation = nil

        if let analyzer {
            await analyzer.cancelAndFinishNow()
        }

        cleanupSession()
    }

    var liveDisplayText: String {
        transcriptBuffer.displayText
    }

    private func makeTranscriber(locale: Locale) async throws -> SpeechTranscriber {
        guard let resolved = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
            throw SpeechEngineError.localeNotSupported
        }

        return SpeechTranscriber(
            locale: resolved,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: []
        )
    }

    private func installAssetsIfNeeded(for transcriber: SpeechTranscriber) async throws {
        guard let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) else {
            downloadProgress = nil
            return
        }

        downloadProgress = request.progress
        try await request.downloadAndInstall()
        downloadProgress = nil
    }

    private func cleanupSession() {
        resultsTask?.cancel()
        resultsTask = nil
        eventContinuation?.finish()
        eventContinuation = nil
        analyzer = nil
        transcriber = nil
        bufferConverter = nil
        isSessionActive = false
    }
}
