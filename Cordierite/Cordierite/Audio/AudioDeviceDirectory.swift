import CoreAudio
import Foundation

enum AudioDeviceDirectoryError: Error {
  case queryFailed(OSStatus)
}

/// Read-only access to the CoreAudio device graph. Kept as a narrow protocol so
/// `InputDeviceResolver`'s decision logic can be exercised without touching real
/// hardware once a test target exists.
protocol AudioDeviceDirectory {
  /// All input-capable devices currently present in the HAL, in HAL enumeration order.
  func liveDeviceIDs() throws -> [AudioDeviceID]

  /// The system's current default input device. May point at a device that is no
  /// longer present in `liveDeviceIDs()` if macOS hasn't updated it yet (e.g. right
  /// after a Bluetooth headset disconnects).
  func defaultInputDeviceID() throws -> AudioDeviceID

  func uid(for deviceID: AudioDeviceID) -> String?

  /// Diagnostics-only. Best-effort; never throws.
  func name(for deviceID: AudioDeviceID) -> String
  func nominalSampleRate(for deviceID: AudioDeviceID) -> Double?
  func inputStreamDescription(for deviceID: AudioDeviceID) -> (
    sampleRate: Double, channels: UInt32
  )?
}

/// CoreAudio-backed implementation. This intentionally never writes to any
/// system-wide property (e.g. `kAudioHardwarePropertyDefaultInputDevice`) — device
/// selection for capture is scoped to this app's own `AVAudioEngine` instance
/// instead (see `AudioCaptureSession`).
struct CoreAudioDeviceDirectory: AudioDeviceDirectory {
  func liveDeviceIDs() throws -> [AudioDeviceID] {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDevices,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )

    var size: UInt32 = 0
    var status = AudioObjectGetPropertyDataSize(
      AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size)
    guard status == noErr else {
      throw AudioDeviceDirectoryError.queryFailed(status)
    }

    let count = Int(size) / MemoryLayout<AudioDeviceID>.size
    var ids = [AudioDeviceID](repeating: 0, count: count)
    status = AudioObjectGetPropertyData(
      AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &ids)
    guard status == noErr else {
      throw AudioDeviceDirectoryError.queryFailed(status)
    }
    return ids.filter { hasInputStreams(deviceID: $0) }
  }

  private func hasInputStreams(deviceID: AudioDeviceID) -> Bool {
    inputStreamDescription(for: deviceID) != nil
  }

  func defaultInputDeviceID() throws -> AudioDeviceID {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDefaultInputDevice,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )

    var id = AudioDeviceID(0)
    var size = UInt32(MemoryLayout<AudioDeviceID>.size)
    let status = AudioObjectGetPropertyData(
      AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &id)
    guard status == noErr else {
      throw AudioDeviceDirectoryError.queryFailed(status)
    }
    return id
  }

  func uid(for deviceID: AudioDeviceID) -> String? {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyDeviceUID,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )

    var uid: Unmanaged<CFString>?
    var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
    let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &uid)
    guard status == noErr, let uid else {
      return nil
    }
    return uid.takeRetainedValue() as String
  }

  func name(for deviceID: AudioDeviceID) -> String {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioObjectPropertyName,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    var name: CFString?
    var size = UInt32(MemoryLayout<CFString?>.size)
    let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &name)
    if status == noErr, let name {
      return name as String
    }
    return uid(for: deviceID) ?? "\(deviceID)"
  }

  func nominalSampleRate(for deviceID: AudioDeviceID) -> Double? {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyNominalSampleRate,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    var rate = Float64(0)
    var size = UInt32(MemoryLayout<Float64>.size)
    let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &rate)
    guard status == noErr else { return nil }
    return rate
  }

  func inputStreamDescription(for deviceID: AudioDeviceID) -> (
    sampleRate: Double, channels: UInt32
  )? {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyStreamFormat,
      mScope: kAudioObjectPropertyScopeInput,
      mElement: kAudioObjectPropertyElementMain
    )
    var asbd = AudioStreamBasicDescription()
    var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
    let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &asbd)
    guard status == noErr else { return nil }
    return (asbd.mSampleRate, asbd.mChannelsPerFrame)
  }
}
