import AVFoundation
import CoreAudio
import Foundation

enum AudioCaptureError: LocalizedError {
    case engineStartFailed
    case deviceNotFound

    var errorDescription: String? {
        switch self {
        case .engineStartFailed:
            "Could not start audio capture."
        case .deviceNotFound:
            "No microphone input device found."
        }
    }
}

@MainActor
final class AudioCaptureSession {
    private let engine = AVAudioEngine()
    private var isCapturing = false

    var inputFormat: AVAudioFormat {
        engine.inputNode.outputFormat(forBus: 0)
    }

    func start(deviceUID: String?, tapHandler: @escaping AVAudioNodeTapBlock) throws {
        guard !isCapturing else {
            return
        }

        if let deviceUID {
            try setDefaultInputDevice(uid: deviceUID)
        }

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format, block: tapHandler)

        engine.prepare()
        do {
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            throw AudioCaptureError.engineStartFailed
        }

        isCapturing = true
    }

    func stop() {
        guard isCapturing else {
            return
        }

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isCapturing = false
    }

    private func setDefaultInputDevice(uid: String) throws {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize
        )
        guard status == noErr else {
            throw AudioCaptureError.deviceNotFound
        }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceIDs
        )
        guard status == noErr else {
            throw AudioCaptureError.deviceNotFound
        }

        for deviceID in deviceIDs {
            guard deviceUID(for: deviceID) == uid else {
                continue
            }

            var defaultInputAddress = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultInputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var mutableDeviceID = deviceID
            let setSize = UInt32(MemoryLayout<AudioDeviceID>.size)
            status = AudioObjectSetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &defaultInputAddress,
                0,
                nil,
                setSize,
                &mutableDeviceID
            )
            guard status == noErr else {
                throw AudioCaptureError.deviceNotFound
            }
            return
        }

        throw AudioCaptureError.deviceNotFound
    }

    private func deviceUID(for deviceID: AudioDeviceID) -> String? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var uid: Unmanaged<CFString>?
        var dataSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &uid
        )

        guard status == noErr, let uid else {
            return nil
        }

        return uid.takeRetainedValue() as String
    }
}
