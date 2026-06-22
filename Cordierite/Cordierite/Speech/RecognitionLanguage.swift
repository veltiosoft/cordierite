import Foundation
import Speech

enum RecognitionLanguageResolver {
    static func locale(for option: RecognitionLanguageOption) -> Locale {
        switch option {
        case .system:
            Locale.current
        case .english:
            Locale(identifier: "en-US")
        case .japanese:
            Locale(identifier: "ja-JP")
        }
    }

    static func resolvedLocale(for option: RecognitionLanguageOption) async -> Locale? {
        await SpeechTranscriber.supportedLocale(equivalentTo: locale(for: option))
    }
}
