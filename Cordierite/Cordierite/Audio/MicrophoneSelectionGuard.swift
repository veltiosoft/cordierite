import Foundation

/// Keeps the configured microphone selection valid by resetting it to System
/// Default whenever the device is unavailable — either because it dropped out
/// of the live device list, or because starting a recording against it failed
/// with `deviceNotFound`.
@MainActor
struct MicrophoneSelectionGuard {
  let configStore: ConfigStore

  /// Resets the selection if it is missing from `availableMicrophones`.
  /// Returns whether a reset happened.
  func reconcile(availableMicrophones: [MicrophoneDevice]) -> Bool {
    guard let selectedDeviceID = configStore.configuration.microphoneDeviceID,
      !availableMicrophones.contains(where: { $0.id == selectedDeviceID })
    else {
      return false
    }
    NSLog("Selected microphone \(selectedDeviceID) is no longer available.")
    reset()
    return true
  }

  func reset() {
    configStore.update { $0.microphoneDeviceID = nil }
    configStore.save()
  }
}
