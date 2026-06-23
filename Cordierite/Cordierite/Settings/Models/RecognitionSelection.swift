import Foundation

enum RecognitionSelection: Hashable, Identifiable, Sendable {
    case appleSpeech
    case whisper(WhisperModelOption)

    nonisolated static var allCases: [RecognitionSelection] {
        [.appleSpeech] + WhisperModelOption.allCases.map { .whisper($0) }
    }

    nonisolated var id: String {
        switch self {
        case .appleSpeech:
            "appleSpeech"
        case .whisper(let model):
            "whisper-\(model.rawValue)"
        }
    }
}
