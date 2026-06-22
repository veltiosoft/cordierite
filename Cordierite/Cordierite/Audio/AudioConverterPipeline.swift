import AVFoundation
import Foundation

enum AudioConverterError: Error {
    case conversionFailed
}

final class AudioBufferConverter: @unchecked Sendable {
    private let targetFormat: AVAudioFormat
    private var converter: AVAudioConverter?

    init(targetFormat: AVAudioFormat) {
        self.targetFormat = targetFormat
    }

    func convertBuffer(_ buffer: AVAudioPCMBuffer) throws -> AVAudioPCMBuffer {
        if converter == nil || converter?.inputFormat != buffer.format {
            guard let newConverter = AVAudioConverter(from: buffer.format, to: targetFormat) else {
                throw AudioConverterError.conversionFailed
            }
            converter = newConverter
        }

        guard let converter else {
            throw AudioConverterError.conversionFailed
        }

        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1
        guard let output = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else {
            throw AudioConverterError.conversionFailed
        }

        var supplied = false
        var conversionError: NSError?
        let status = converter.convert(to: output, error: &conversionError) { _, outStatus in
            if supplied {
                outStatus.pointee = .noDataNow
                return nil
            }
            supplied = true
            outStatus.pointee = .haveData
            return buffer
        }

        guard status != .error else {
            let code = conversionError?.code ?? -1
            NSLog("AVAudioConverter failed with OSStatus \(code)")
            throw conversionError ?? AudioConverterError.conversionFailed
        }

        if output.frameLength == 0 {
            throw AudioConverterError.conversionFailed
        }

        return output
    }
}
