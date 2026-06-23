import AVFoundation
import Foundation

enum WhisperPCMBuffer {
    static let sampleRate: Double = 16_000

    private static let targetFormat: AVAudioFormat? = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: sampleRate,
        channels: 1,
        interleaved: false
    )

    final class Accumulator: @unchecked Sendable {
        private let lock = NSLock()
        private var converter: AudioBufferConverter?
        private var samples: [Float] = []

        func reset() {
            lock.lock()
            samples = []
            converter = nil
            lock.unlock()
        }

        func append(_ buffer: AVAudioPCMBuffer) throws {
            guard let targetFormat = WhisperPCMBuffer.targetFormat else {
                throw SpeechEngineError.conversionFailed
            }

            lock.lock()
            if converter == nil {
                converter = AudioBufferConverter(targetFormat: targetFormat)
            }
            let converter = converter
            lock.unlock()

            guard let converter else {
                throw SpeechEngineError.conversionFailed
            }

            let converted = try converter.convertBuffer(buffer)
            guard let channelData = converted.floatChannelData else {
                throw SpeechEngineError.conversionFailed
            }

            let frameLength = Int(converted.frameLength)
            guard frameLength > 0 else {
                return
            }

            let newSamples = Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))

            lock.lock()
            samples.append(contentsOf: newSamples)
            lock.unlock()
        }

        func snapshot() -> [Float] {
            lock.lock()
            defer { lock.unlock() }
            return samples
        }

        var duration: TimeInterval {
            lock.lock()
            defer { lock.unlock() }
            return Double(samples.count) / WhisperPCMBuffer.sampleRate
        }
    }
}
