import Foundation

enum InputMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case hold
    case toggle

    var id: String { rawValue }

    var label: String {
        switch self {
        case .hold:
            "Hold to Talk"
        case .toggle:
            "Toggle"
        }
    }
}

enum HotkeyOption: String, Codable, CaseIterable, Identifiable, Sendable {
    case rightOption
    case rightCommand
    case f13

    var id: String { rawValue }

    var label: String {
        switch self {
        case .rightOption:
            "Right Option"
        case .rightCommand:
            "Right Command"
        case .f13:
            "F13"
        }
    }
}

enum RecognitionLanguageOption: String, Codable, CaseIterable, Identifiable, Sendable {
    case system
    case english
    case japanese

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system:
            "System Default"
        case .english:
            "English"
        case .japanese:
            "Japanese"
        }
    }
}

enum RecognitionEngineOption: String, Codable, CaseIterable, Identifiable, Sendable {
    case appleSpeech
    case whisper

    var id: String { rawValue }

    var label: String {
        switch self {
        case .appleSpeech:
            "Apple Speech"
        case .whisper:
            "Whisper"
        }
    }
}

enum WhisperLanguageOption: String, Codable, CaseIterable, Identifiable, Sendable {
    case auto
    case english
    case japanese

    var id: String { rawValue }

    var label: String {
        switch self {
        case .auto:
            "Auto Detect"
        case .english:
            "English"
        case .japanese:
            "Japanese"
        }
    }

    var whisperCode: String? {
        switch self {
        case .auto:
            nil
        case .english:
            "en"
        case .japanese:
            "ja"
        }
    }
}

struct WhisperConfiguration: Codable, Equatable, Sendable {
    var model: String = WhisperModelCatalog.defaultModelID
    var language: WhisperLanguageOption = .auto
}

enum PasteMethodOption: String, Codable, CaseIterable, Identifiable, Sendable {
    case pasteboardCommandV

    var id: String { rawValue }

    var label: String {
        switch self {
        case .pasteboardCommandV:
            "Pasteboard + Command V"
        }
    }
}

struct AppConfiguration: Codable, Equatable, Sendable {
    var inputMode: InputMode = .hold
    var hotkey: HotkeyOption = .rightOption
    var language: RecognitionLanguageOption = .system
    var microphoneDeviceID: String?
    var recognitionEngine: RecognitionEngineOption = .appleSpeech
    var whisper: WhisperConfiguration = WhisperConfiguration()
    var pasteMethod: PasteMethodOption = .pasteboardCommandV
    var maxRecordingSeconds: Int = 120
    var restoreClipboardText: Bool = true
}
