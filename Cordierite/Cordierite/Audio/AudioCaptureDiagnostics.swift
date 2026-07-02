import AVFoundation
import CoreAudio
import Foundation

/// All `NSLog` diagnostics for `AudioCaptureSession`, kept in one place so the
/// capture/bind/validate flow in `AudioCaptureSession` itself stays readable.
enum AudioCaptureDiagnostics {
  static func logStartRequested(deviceUID: String?) {
    NSLog("AudioCaptureSession: start requested deviceUID=\(deviceUID ?? "system-default")")
  }

  static func logAllDevices(directory: AudioDeviceDirectory) {
    guard let ids = try? directory.liveDeviceIDs() else {
      NSLog("AudioCaptureSession: failed to enumerate devices")
      return
    }
    NSLog("AudioCaptureSession: present devices count=\(ids.count)")
    for id in ids {
      logDeviceDescription(id: id, label: "  device", directory: directory)
    }
  }

  static func logDeviceDescription(
    id: AudioDeviceID, label: String, directory: AudioDeviceDirectory
  ) {
    let uid = directory.uid(for: id) ?? "n/a"
    let name = directory.name(for: id)
    let nominal = directory.nominalSampleRate(for: id).map { "\($0) Hz" } ?? "n/a"
    let stream =
      directory.inputStreamDescription(for: id).map { "\($0.sampleRate) Hz / \($0.channels) ch" }
      ?? "n/a"
    NSLog(
      """
      AudioCaptureSession: \(label) device id=\(id) name=\"\(name)\" \
      uid=\(uid) nominal=\(nominal) inputStream=\(stream)
      """
    )
  }

  static func logResolution(_ resolution: ResolvedInputDevice, directory: AudioDeviceDirectory) {
    switch resolution {
    case .systemDefault:
      NSLog("AudioCaptureSession: using system default input (no explicit device bind)")
    case .specific(let id):
      logDeviceDescription(id: id, label: "resolved(specific)", directory: directory)
    case .fallback(let id):
      NSLog("AudioCaptureSession: system default input is stale, falling back")
      logDeviceDescription(id: id, label: "resolved(fallback)", directory: directory)
    }
  }

  static func logBindFailure(id: AudioDeviceID, error: Error) {
    NSLog("AudioCaptureSession: setDeviceID failed for id=\(id): \(error)")
  }

  static func logFormatProbe(
    deviceUID: String?,
    format: AVAudioFormat,
    hardwareInputFormat: AVAudioFormat
  ) {
    NSLog(
      """
      AudioCaptureSession: requested=\(deviceUID ?? "system-default"), \
      tap format \(format.sampleRate) Hz / \(format.channelCount) ch, \
      hardware input \(hardwareInputFormat.sampleRate) Hz / \(hardwareInputFormat.channelCount) ch
      """
    )
  }

  static func logInvalidFormat(_ format: AVAudioFormat, hardwareInputFormat: AVAudioFormat) {
    NSLog(
      """
      AudioCaptureSession: invalid tap format — output \(format.sampleRate) Hz/\(format.channelCount) ch, \
      hardware input \(hardwareInputFormat.sampleRate) Hz/\(hardwareInputFormat.channelCount) ch
      """
    )
  }

  static func logEngineStartFailed(_ error: Error) {
    NSLog("AudioCaptureSession: AVAudioEngine.start failed: \(error)")
  }

  static func logRetrying(after error: Error) {
    NSLog("AudioCaptureSession: retrying start once after failure: \(error)")
  }

  static func logReusingEngine() {
    NSLog("AudioCaptureSession: reusing existing engine (resolved device unchanged)")
  }

  static func logDefaultDeviceChanged() {
    NSLog(
      "AudioCaptureSession: system default input device changed; will rebind on next start")
  }

  /// Always-on (not gated behind DEBUG) timing breakdown so a slow-to-start
  /// recording can be diagnosed from Console.app without rebuilding.
  static func logDuration(_ label: String, _ duration: Duration) {
    let components = duration.components
    let milliseconds =
      Double(components.seconds) * 1000 + Double(components.attoseconds) / 1_000_000_000_000_000
    NSLog(String(format: "AudioCaptureSession: %@ took %.1f ms", label, milliseconds))
  }
}
