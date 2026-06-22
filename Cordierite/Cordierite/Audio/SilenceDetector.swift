import AVFoundation
import Foundation

final class SilenceDetector: @unchecked Sendable {
    static let minimumDuration: TimeInterval = 0.3
    static let minimumRMS: Float = 0.003

    private let lock = NSLock()
    private var peakRMS: Float = 0

    func process(buffer: AVAudioPCMBuffer) {
        guard let rms = Self.rms(for: buffer) else {
            return
        }

        lock.lock()
        peakRMS = max(peakRMS, rms)
        lock.unlock()
    }

    func shouldDiscard(duration: TimeInterval) -> Bool {
        lock.lock()
        let peak = peakRMS
        lock.unlock()

        return duration < Self.minimumDuration || peak < Self.minimumRMS
    }

    func reset() {
        lock.lock()
        peakRMS = 0
        lock.unlock()
    }

    var currentPeakRMS: Float {
        lock.lock()
        defer { lock.unlock() }
        return peakRMS
    }

    private static func rms(for buffer: AVAudioPCMBuffer) -> Float? {
        guard let channelData = buffer.floatChannelData else {
            return nil
        }

        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else {
            return nil
        }

        let channelCount = Int(buffer.format.channelCount)
        var sumSquares: Double = 0
        var sampleCount = 0

        for channel in 0..<channelCount {
            let samples = channelData[channel]
            for index in 0..<frameLength {
                let sample = Double(samples[index])
                sumSquares += sample * sample
                sampleCount += 1
            }
        }

        guard sampleCount > 0 else {
            return nil
        }

        return Float(sqrt(sumSquares / Double(sampleCount)))
    }
}
