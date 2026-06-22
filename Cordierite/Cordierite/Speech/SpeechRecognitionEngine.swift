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
        }
    }
}

protocol SpeechRecognitionEngine: AnyObject {
    @MainActor func prepare(language: RecognitionLanguageOption) async throws
    @MainActor func start(language: RecognitionLanguageOption) async throws -> AsyncThrowingStream<RecognitionEvent, Error>
    @MainActor func processAudioBuffer(_ buffer: AVAudioPCMBuffer) throws
    @MainActor func stop() async throws -> String
    @MainActor func cancelSession() async
}
