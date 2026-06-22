import AVFoundation

extension AVAudioPCMBuffer {
    func deepCopy() -> AVAudioPCMBuffer? {
        guard frameLength > 0, format.sampleRate > 0 else {
            return nil
        }

        guard let copied = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameLength) else {
            return nil
        }

        copied.frameLength = frameLength

        guard let sourceChannels = floatChannelData,
              let destinationChannels = copied.floatChannelData else {
            return nil
        }

        let channelCount = Int(format.channelCount)
        let byteCount = Int(frameLength) * MemoryLayout<Float>.size

        for channel in 0..<channelCount {
            memcpy(destinationChannels[channel], sourceChannels[channel], byteCount)
        }

        return copied
    }
}
