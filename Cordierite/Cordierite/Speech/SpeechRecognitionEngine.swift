import AVFoundation
import Foundation

enum RecognitionEvent: Sendable {
    case partial(String)
    case final(String)
}

enum SpeechEngineError: LocalizedError {
    case localeNotSupported
    case transcriberUnavailable
    case analyzerNotConfigured
    case conversionFailed
    case sessionNotActive
    case transcriptionFailed
    case whisperUnavailable
    case whisperModelDownloadFailed
    case whisperModelNotReady

    var errorDescription: String? {
        switch self {
        case .localeNotSupported:
            "The selected language is not supported for speech recognition."
        case .transcriberUnavailable:
            "Apple Speech is not available on this device."
        case .analyzerNotConfigured:
            "Speech analyzer could not be configured."
        case .conversionFailed:
            "Audio conversion for speech recognition failed."
        case .sessionNotActive:
            "Speech recognition is not active."
        case .transcriptionFailed:
            "Could not transcribe this recording."
        case .whisperUnavailable:
            "Whisper is not available on this device."
        case .whisperModelDownloadFailed:
            "Could not download the Whisper model."
        case .whisperModelNotReady:
            "Download the selected Whisper model before recording."
        }
    }
}

@MainActor
protocol SpeechRecognitionEngine: AnyObject {
    var downloadProgress: Progress? { get }
    var liveDisplayText: String { get }
    var loadingStatusMessage: String { get }

    func prepare(language: RecognitionLanguageOption) async throws
    func start(language: RecognitionLanguageOption) async throws -> AsyncThrowingStream<RecognitionEvent, Error>
    func processAudioBuffer(_ buffer: AVAudioPCMBuffer) throws
    func stop() async throws -> String
    func cancelSession() async
    func shutdown() async
}

extension SpeechRecognitionEngine {
    var downloadProgress: Progress? { nil }
    var liveDisplayText: String { "" }
    var loadingStatusMessage: String { "" }
}
