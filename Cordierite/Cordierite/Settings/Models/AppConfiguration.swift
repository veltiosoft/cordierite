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
    var removeFillerWords: Bool = true

    init(
        inputMode: InputMode = .hold,
        hotkey: HotkeyOption = .rightOption,
        language: RecognitionLanguageOption = .system,
        microphoneDeviceID: String? = nil,
        recognitionEngine: RecognitionEngineOption = .appleSpeech,
        whisper: WhisperConfiguration = WhisperConfiguration(),
        pasteMethod: PasteMethodOption = .pasteboardCommandV,
        maxRecordingSeconds: Int = 120,
        restoreClipboardText: Bool = true,
        removeFillerWords: Bool = true
    ) {
        self.inputMode = inputMode
        self.hotkey = hotkey
        self.language = language
        self.microphoneDeviceID = microphoneDeviceID
        self.recognitionEngine = recognitionEngine
        self.whisper = whisper
        self.pasteMethod = pasteMethod
        self.maxRecordingSeconds = maxRecordingSeconds
        self.restoreClipboardText = restoreClipboardText
        self.removeFillerWords = removeFillerWords
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        inputMode = try container.decode(InputMode.self, forKey: .inputMode)
        hotkey = try container.decode(HotkeyOption.self, forKey: .hotkey)
        language = try container.decode(RecognitionLanguageOption.self, forKey: .language)
        microphoneDeviceID = try container.decodeIfPresent(String.self, forKey: .microphoneDeviceID)
        recognitionEngine = try container.decode(RecognitionEngineOption.self, forKey: .recognitionEngine)
        whisper = try container.decode(WhisperConfiguration.self, forKey: .whisper)
        pasteMethod = try container.decode(PasteMethodOption.self, forKey: .pasteMethod)
        maxRecordingSeconds = try container.decode(Int.self, forKey: .maxRecordingSeconds)
        restoreClipboardText = try container.decode(Bool.self, forKey: .restoreClipboardText)
        removeFillerWords = try container.decodeIfPresent(Bool.self, forKey: .removeFillerWords) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(inputMode, forKey: .inputMode)
        try container.encode(hotkey, forKey: .hotkey)
        try container.encode(language, forKey: .language)
        try container.encodeIfPresent(microphoneDeviceID, forKey: .microphoneDeviceID)
        try container.encode(recognitionEngine, forKey: .recognitionEngine)
        try container.encode(whisper, forKey: .whisper)
        try container.encode(pasteMethod, forKey: .pasteMethod)
        try container.encode(maxRecordingSeconds, forKey: .maxRecordingSeconds)
        try container.encode(restoreClipboardText, forKey: .restoreClipboardText)
        try container.encode(removeFillerWords, forKey: .removeFillerWords)
    }

    private enum CodingKeys: String, CodingKey {
        case inputMode
        case hotkey
        case language
        case microphoneDeviceID
        case recognitionEngine
        case whisper
        case pasteMethod
        case maxRecordingSeconds
        case restoreClipboardText
        case removeFillerWords
    }
}
