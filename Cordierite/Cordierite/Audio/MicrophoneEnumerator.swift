import AVFoundation
import Foundation

struct MicrophoneDevice: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
}

enum MicrophoneEnumerator {
    static func availableDevices() -> [MicrophoneDevice] {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: .audio,
            position: .unspecified
        )

        return discoverySession.devices.map { device in
            MicrophoneDevice(id: device.uniqueID, name: device.localizedName)
        }
    }

    static func displayName(for deviceID: String?) -> String {
        guard let deviceID else {
            return "System Default"
        }

        return availableDevices().first(where: { $0.id == deviceID })?.name ?? "Unknown Device"
    }
}
