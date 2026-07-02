import CoreAudio
import Foundation

/// Which input device `AudioCaptureSession` should bind its `AVAudioEngine` to.
///
/// `.systemDefault` means "don't call `setDeviceID` at all" — the engine's input
/// node keeps following whatever the system default input is, including future
/// changes made while capturing.
enum ResolvedInputDevice: Equatable {
  case specific(AudioDeviceID)
  case systemDefault
  case fallback(AudioDeviceID)
}

/// Pure decision logic for picking an input device. Depends only on plain data
/// (no CoreAudio calls, no `AVAudioEngine`), so it can be unit tested once a test
/// target exists, without touching real hardware.
enum InputDeviceResolver {
  /// - Parameters:
  ///   - requestedUID: The device UID the user configured, or `nil` for "System Default".
  ///   - liveDeviceIDs: Devices CoreAudio currently reports as present. This is the
  ///     single source of truth for device identity here — deliberately not
  ///     cross-matched against `MicrophoneEnumerator`'s AVFoundation-based list, to
  ///     avoid depending on two device-listing APIs staying in sync.
  ///   - defaultDeviceID: The system's current default input device (may be stale).
  ///     Optional because the query can fail even when a specific requested device
  ///     is still present in `liveDeviceIDs`.
  ///   - uidLookup: Resolves a UID for a given device ID (from `AudioDeviceDirectory`).
  static func resolve(
    requestedUID: String?,
    liveDeviceIDs: [AudioDeviceID],
    defaultDeviceID: AudioDeviceID?,
    uidLookup: (AudioDeviceID) -> String?
  ) -> Result<ResolvedInputDevice, AudioCaptureError> {
    if let requestedUID {
      guard let match = liveDeviceIDs.first(where: { uidLookup($0) == requestedUID }) else {
        return .failure(.deviceNotFound)
      }

      // If the requested device already is the system default, there's no need
      // to explicitly bind the engine to it — an explicit `setDeviceID` forces
      // CoreAudio to re-negotiate the device even when nothing would actually
      // change, which is a needless source of startup latency.
      if let defaultDeviceID, match == defaultDeviceID {
        return .success(.systemDefault)
      }
      return .success(.specific(match))
    }

    if let defaultDeviceID, liveDeviceIDs.contains(defaultDeviceID) {
      return .success(.systemDefault)
    }

    // The system default points at a device that's no longer present (e.g. a
    // just-disconnected Bluetooth headset). Bind this app's engine directly to a
    // live input device instead — this only affects Cordierite's own capture,
    // unlike the old approach of rewriting the system-wide default input device.
    guard let fallback = liveDeviceIDs.first else {
      return .failure(.deviceNotFound)
    }
    return .success(.fallback(fallback))
  }
}
