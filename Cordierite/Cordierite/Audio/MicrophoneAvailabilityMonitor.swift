import AVFoundation
import Foundation

/// Observes microphone connect/disconnect notifications so `AppModel` can react to
/// hot-plug events (e.g. unplugging a USB mic, a Bluetooth headset dropping out)
/// without requiring the user to manually press "Reload Devices".
@MainActor
final class MicrophoneAvailabilityMonitor {
  private var observers: [NSObjectProtocol] = []

  /// - Parameter onChange: Called on the main actor whenever a microphone is
  ///   connected or disconnected.
  func start(onChange: @escaping @MainActor () -> Void) {
    stop()

    let center = NotificationCenter.default
    let names = [
      AVCaptureDevice.wasConnectedNotification,
      AVCaptureDevice.wasDisconnectedNotification,
    ]

    observers = names.map { name in
      center.addObserver(forName: name, object: nil, queue: .main) { _ in
        Task { @MainActor in
          onChange()
        }
      }
    }
  }

  func stop() {
    let center = NotificationCenter.default
    for observer in observers {
      center.removeObserver(observer)
    }
    observers.removeAll()
  }
}
