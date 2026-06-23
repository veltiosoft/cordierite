import Foundation

@MainActor
enum SpeechEngineFactory {
    static func makeEngine(
        for option: RecognitionEngineOption,
        whisperConfiguration: WhisperConfiguration
    ) -> any SpeechRecognitionEngine {
        switch option {
        case .appleSpeech:
            SpeechAnalyzerEngine()
        case .whisper:
            WhisperEngine(whisperConfiguration: whisperConfiguration)
        }
    }
}
