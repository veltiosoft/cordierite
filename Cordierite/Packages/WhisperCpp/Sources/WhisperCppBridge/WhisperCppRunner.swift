import Foundation
import whisper

public enum WhisperCppBridgeError: Error, LocalizedError, Sendable {
    case failedToLoadModel(String)
    case transcriptionFailed(Int32)

    public var errorDescription: String? {
        switch self {
        case .failedToLoadModel(let path):
            "Failed to load Whisper model at \(path)."
        case .transcriptionFailed(let code):
            "Whisper transcription failed with code \(code)."
        }
    }
}

public actor WhisperCppRunner {
    private nonisolated(unsafe) let context: OpaquePointer

    public init(modelPath: String) throws {
        var params = whisper_context_default_params()
        params.use_gpu = true
        params.flash_attn = true

        guard let context = whisper_init_from_file_with_params(modelPath, params) else {
            throw WhisperCppBridgeError.failedToLoadModel(modelPath)
        }

        self.context = context
    }

    deinit {
        whisper_free(context)
    }

    public func warmup() throws {
        let silence = [Float](repeating: 0, count: 16_000)
        _ = try transcribe(samples: silence, language: "en")
    }

    public func transcribe(samples: [Float], language: String?) throws -> String {
        guard !samples.isEmpty else {
            return ""
        }

        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        params.print_progress = false
        params.print_realtime = false
        params.print_timestamps = false
        params.print_special = false
        params.translate = false
        params.no_context = true
        params.n_threads = Int32(max(1, ProcessInfo.processInfo.activeProcessorCount - 1))

        let code: Int32 = samples.withUnsafeBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else {
                return -1
            }

            if let language {
                return language.withCString { languagePointer in
                    var configured = params
                    configured.language = languagePointer
                    return whisper_full(context, configured, baseAddress, Int32(buffer.count))
                }
            }

            return whisper_full(context, params, baseAddress, Int32(buffer.count))
        }

        guard code == 0 else {
            throw WhisperCppBridgeError.transcriptionFailed(code)
        }

        var text = ""
        let segmentCount = whisper_full_n_segments(context)
        for index in 0..<segmentCount {
            if let segmentText = whisper_full_get_segment_text(context, index) {
                text += String(cString: segmentText)
            }
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
