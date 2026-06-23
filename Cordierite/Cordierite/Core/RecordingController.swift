import AVFoundation
import Foundation

enum RecordingStopResult: Sendable {
    case accepted(duration: TimeInterval, peakRMS: Float, transcript: String)
    case discardedSilence(duration: TimeInterval, peakRMS: Float)
    case failed(String)
}

private final class PCMBufferBox: @unchecked Sendable {
    let buffer: AVAudioPCMBuffer

    init(_ buffer: AVAudioPCMBuffer) {
        self.buffer = buffer
    }
}

@MainActor
final class RecordingController {
    private let audioCapture = AudioCaptureSession()
    private let silenceDetector = SilenceDetector()
    private var speechEngine: any SpeechRecognitionEngine
    private var recordingStartedAt: Date?
    private var maxDurationTask: Task<Void, Never>?
    private var recognitionTask: Task<Void, Never>?
    private var audioFeedTask: Task<Void, Never>?
    private var audioStreamContinuation: AsyncStream<PCMBufferBox>.Continuation?

    var onMaxDurationReached: (@MainActor () async -> Void)?
    var onRecognitionEvent: (@MainActor (RecognitionEvent) -> Void)?

    var isRecording: Bool {
        recordingStartedAt != nil
    }

    init(speechEngine: any SpeechRecognitionEngine) {
        self.speechEngine = speechEngine
    }

    func setSpeechEngine(_ speechEngine: any SpeechRecognitionEngine) {
        self.speechEngine = speechEngine
    }

    func start(
        deviceUID: String?,
        maxRecordingSeconds: Int,
        language: RecognitionLanguageOption
    ) async throws {
        guard !isRecording else {
            return
        }

        silenceDetector.reset()
        recordingStartedAt = Date()

        let stream = try await speechEngine.start(language: language)
        recognitionTask = Task {
            do {
                for try await event in stream {
                    onRecognitionEvent?(event)
                }
            } catch {
                NSLog("Speech recognition stream failed: \(error.localizedDescription)")
            }
        }

        let audioStream = AsyncStream<PCMBufferBox>.makeStream()
        audioStreamContinuation = audioStream.continuation
        audioFeedTask = Task {
            for await box in audioStream.stream {
                guard !Task.isCancelled else {
                    break
                }

                do {
                    try speechEngine.processAudioBuffer(box.buffer)
                } catch {
                    NSLog("Speech audio conversion failed: \(error.localizedDescription)")
                }
            }
        }

        try audioCapture.start(deviceUID: deviceUID) { [silenceDetector] buffer, _ in
            silenceDetector.process(buffer: buffer)
            guard let copied = buffer.deepCopy() else {
                return
            }
            audioStream.continuation.yield(PCMBufferBox(copied))
        }

        maxDurationTask?.cancel()
        maxDurationTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(maxRecordingSeconds))
            guard !Task.isCancelled, let self, self.isRecording else {
                return
            }
            await self.onMaxDurationReached?()
        }
    }

    func stop() async -> RecordingStopResult {
        maxDurationTask?.cancel()
        maxDurationTask = nil

        audioCapture.stop()
        audioStreamContinuation?.finish()
        audioStreamContinuation = nil
        audioFeedTask?.cancel()
        audioFeedTask = nil

        guard let startedAt = recordingStartedAt else {
            await speechEngine.cancelSession()
            recognitionTask?.cancel()
            recognitionTask = nil
            return .failed("Recording was not active.")
        }

        recordingStartedAt = nil
        let duration = Date().timeIntervalSince(startedAt)
        let peakRMS = silenceDetector.currentPeakRMS

        if silenceDetector.shouldDiscard(duration: duration) {
            await speechEngine.cancelSession()
            recognitionTask?.cancel()
            recognitionTask = nil
            return .discardedSilence(duration: duration, peakRMS: peakRMS)
        }

        do {
            let transcript = try await speechEngine.stop()
            recognitionTask?.cancel()
            recognitionTask = nil
            return .accepted(duration: duration, peakRMS: peakRMS, transcript: transcript)
        } catch {
            await speechEngine.cancelSession()
            recognitionTask?.cancel()
            recognitionTask = nil
            return .failed(error.localizedDescription)
        }
    }
}
