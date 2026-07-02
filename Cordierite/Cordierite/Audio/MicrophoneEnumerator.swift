import AVFoundation
import CoreAudio
import Foundation

struct MicrophoneDevice: Identifiable, Equatable, Sendable {
  enum TransportType: Equatable, Sendable {
    case builtIn
    case usb
    case bluetooth
    case other
  }

  let id: String
  let name: String
  let transportType: TransportType
}

/// Lists microphones for display in the Settings / menu-bar pickers, via
/// AVFoundation.
///
/// This is intentionally independent from the CoreAudio-based device resolution
/// `AudioCaptureSession`/`InputDeviceResolver` use for actual capture: the two are
/// never cross-matched by UID, so the two device-listing APIs drifting out of sync
/// can't cause capture to bind to the wrong device. This enumerator only feeds UI.
enum MicrophoneEnumerator {
  static func availableDevices() -> [MicrophoneDevice] {
    let discoverySession = AVCaptureDevice.DiscoverySession(
      deviceTypes: [.microphone, .external],
      mediaType: .audio,
      position: .unspecified
    )

    return discoverySession.devices.map { device in
      MicrophoneDevice(
        id: device.uniqueID,
        name: device.localizedName,
        transportType: transportType(for: device)
      )
    }
  }

  static func displayName(for deviceID: String?) -> String {
    guard let deviceID else {
      return "System Default"
    }

    return availableDevices().first(where: { $0.id == deviceID })?.name ?? "Unknown Device"
  }

  private static func transportType(for device: AVCaptureDevice) -> MicrophoneDevice.TransportType {
    switch UInt32(bitPattern: device.transportType) {
    case kAudioDeviceTransportTypeBuiltIn:
      .builtIn
    case kAudioDeviceTransportTypeUSB:
      .usb
    case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE:
      .bluetooth
    default:
      .other
    }
  }
}
