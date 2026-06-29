import AVFoundation
import CoreAudio
import Foundation

enum AudioCaptureError: LocalizedError, Equatable {
  case engineStartFailed
  case deviceNotFound
  case noInputReceived

  var errorDescription: String? {
    switch self {
    case .engineStartFailed:
      "Could not start audio capture."
    case .deviceNotFound:
      "No microphone input device found."
    case .noInputReceived:
      "Microphone input did not become active."
    }
  }
}

private nonisolated final class FirstAudioBufferGate: @unchecked Sendable {
  private let lock = NSLock()
  private var continuation: CheckedContinuation<Void, Error>?
  private var result: Result<Void, Error>?

  nonisolated func signalIfNeeded(buffer: AVAudioPCMBuffer) {
    guard buffer.frameLength > 0 else {
      return
    }

    finish(with: .success(()))
  }

  nonisolated func wait(timeout: Duration) async throws {
    let timeoutTask = Task { [weak self] in
      try? await Task.sleep(for: timeout)
      self?.finish(with: .failure(AudioCaptureError.noInputReceived))
    }

    defer {
      timeoutTask.cancel()
    }

    try await withCheckedThrowingContinuation { continuation in
      lock.lock()
      if let result {
        lock.unlock()
        continuation.resume(with: result)
        return
      }

      self.continuation = continuation
      lock.unlock()
    }
  }

  private nonisolated func finish(with result: Result<Void, Error>) {
    let continuation: CheckedContinuation<Void, Error>?

    lock.lock()
    guard self.result == nil else {
      lock.unlock()
      return
    }
    self.result = result
    continuation = self.continuation
    self.continuation = nil
    lock.unlock()

    continuation?.resume(with: result)
  }
}

@MainActor
final class AudioCaptureSession {
  // Recreated on every `start` via `refreshEngine` so the input node reports the
  // current default input device's format. A reused AVAudioEngine can keep a
  // stale output format after the default input device changes, which makes
  // `installTap` throw an ObjC NSException (uncatchable in Swift) and crash.
  private var engine = AVAudioEngine()
  private var isCapturing = false

  var inputFormat: AVAudioFormat {
    engine.inputNode.outputFormat(forBus: 0)
  }

  func start(deviceUID: String?, tapHandler: @escaping AVAudioNodeTapBlock) async throws {
    guard !isCapturing else {
      return
    }

    NSLog("AudioCaptureSession: start requested deviceUID=\(deviceUID ?? "system-default")")

    // Snapshot the HAL state up front so we can see what every layer reports.
    logAllDevices()

    let defaultBefore = try? currentDefaultInputDeviceID()
    NSLog(
      "AudioCaptureSession: default input device BEFORE set = \(defaultBefore.map(String.init) ?? "unknown")"
    )

    // Resolve and verify a live input device BEFORE creating the engine. A
    // disconnected Bluetooth headset can remain the system default input; if we
    // let AVAudioEngine's input node bind to that dead device, installTap throws
    // an ObjC NSException (uncatchable in Swift) and crashes the app.
    let resolvedDeviceID = try resolveInputDevice(deviceUID: deviceUID)
    logDeviceDescription(id: resolvedDeviceID, label: "resolved")
    try setDefaultInputDevice(id: resolvedDeviceID)

    let defaultAfter = try? currentDefaultInputDeviceID()
    NSLog(
      "AudioCaptureSession: default input device AFTER set = \(defaultAfter.map(String.init) ?? "unknown")"
    )

    refreshEngine()
    try await startCapture(
      deviceUID: deviceUID, resolvedDeviceID: resolvedDeviceID, tapHandler: tapHandler)
  }

  func stop() {
    guard isCapturing else {
      return
    }

    engine.inputNode.removeTap(onBus: 0)
    engine.stop()
    isCapturing = false
  }

  private func refreshEngine() {
    if isCapturing {
      engine.inputNode.removeTap(onBus: 0)
      engine.stop()
    }
    engine = AVAudioEngine()
  }

  private func startCapture(
    deviceUID: String?,
    resolvedDeviceID: AudioDeviceID,
    tapHandler: @escaping AVAudioNodeTapBlock
  ) async throws {
    let inputNode = engine.inputNode
    let nodeOutputFormat = inputNode.outputFormat(forBus: 0)
    let nodeInputFormat = inputNode.inputFormat(forBus: 0)
    let hwStream = inputStreamDescription(for: resolvedDeviceID)
    let nominal = nominalSampleRate(for: resolvedDeviceID)

    NSLog(
      """
      AudioCaptureSession: format probe — \
      inputNode.output \(nodeOutputFormat.sampleRate) Hz / \(nodeOutputFormat.channelCount) ch, \
      inputNode.input \(nodeInputFormat.sampleRate) Hz / \(nodeInputFormat.channelCount) ch, \
      CoreAudio input stream \(hwStream.map { "\($0.sampleRate) Hz / \($0.channels) ch" } ?? "n/a"), \
      CoreAudio nominal \(nominal.map { "\($0) Hz" } ?? "n/a")
      """)

    let format = nodeOutputFormat
    logInputDiagnostics(
      deviceUID: deviceUID, resolvedDeviceID: resolvedDeviceID, format: format)

    guard isTapFormatValid(format) else {
      throw AudioCaptureError.engineStartFailed
    }

    // Cross-check: if AVAudioEngine's reported output format disagrees with the
    // device's actual hardware stream format, installing a tap on the output bus
    // can throw an ObjC NSException. Log the discrepancy so we can pinpoint it
    // even when validation passes.
    if let hwStream, hwStream.sampleRate > 0,
      abs(hwStream.sampleRate - format.sampleRate) > 1.0
    {
      NSLog(
        """
        AudioCaptureSession: WARN outputFormat \(format.sampleRate) Hz \
        differs from hardware stream \(hwStream.sampleRate) Hz for device \(resolvedDeviceID)
        """
      )
    }

    let firstBufferGate = FirstAudioBufferGate()
    let gatedTapHandler = Self.makeGatedTapHandler(
      firstBufferGate: firstBufferGate,
      tapHandler: tapHandler
    )
    inputNode.removeTap(onBus: 0)
    NSLog(
      "AudioCaptureSession: installTap bus=0 bufferSize=1024 format=\(format.sampleRate) Hz/\(format.channelCount) ch"
    )
    inputNode.installTap(onBus: 0, bufferSize: 1024, format: format, block: gatedTapHandler)

    engine.prepare()
    do {
      try engine.start()
    } catch {
      inputNode.removeTap(onBus: 0)
      NSLog("AVAudioEngine.start failed: \(error)")
      throw AudioCaptureError.engineStartFailed
    }

    isCapturing = true

    do {
      try await waitForFirstInputBuffer(firstBufferGate)
    } catch {
      stop()
      throw error
    }
  }

  private func isTapFormatValid(_ format: AVAudioFormat) -> Bool {
    guard format.sampleRate > 0, format.channelCount > 0 else {
      NSLog(
        "AudioCaptureSession: invalid tap format — \(format.sampleRate) Hz, \(format.channelCount) ch"
      )
      return false
    }

    // The input node's input and output formats should agree on sample rate for
    // a tap on the output bus. A mismatch signals a stale format cache.
    let hardwareFormat = engine.inputNode.inputFormat(forBus: 0)
    if hardwareFormat.sampleRate > 0, hardwareFormat.sampleRate != format.sampleRate {
      NSLog(
        """
        AudioCaptureSession: input/output format mismatch — \
        input \(hardwareFormat.sampleRate) Hz, output \(format.sampleRate) Hz
        """
      )
      return false
    }

    return true
  }

  private func logInputDiagnostics(
    deviceUID: String?, resolvedDeviceID: AudioDeviceID, format: AVAudioFormat
  ) {
    NSLog(
      """
      AudioCaptureSession: requested=\(deviceUID ?? "system-default"), \
      resolvedDeviceID=\(resolvedDeviceID), \
      tap format \(format.sampleRate) Hz, \(format.channelCount) ch
      """
    )
  }

  /// Resolves a concrete, currently-present input device for the requested UID.
  /// - When `deviceUID` is provided, requires that device to still be present
  ///   (throws `deviceNotFound` otherwise — surfaces as reload guidance, no crash).
  /// - When `deviceUID` is nil (System Default), verifies the system default is
  ///   still a live device. If macOS left the default pointing at a just
  ///   disconnected device (e.g. Bluetooth headset), falls back to any present
  ///   input device so recording can proceed without crashing.
  private func resolveInputDevice(deviceUID requestedUID: String?) throws -> AudioDeviceID {
    let deviceIDs = try currentDeviceIDs()

    if let requestedUID {
      guard let id = deviceIDs.first(where: { deviceUID(for: $0) == requestedUID }) else {
        NSLog("AudioCaptureSession: requested device \(requestedUID) not present")
        throw AudioCaptureError.deviceNotFound
      }
      return id
    }

    let defaultID = try currentDefaultInputDeviceID()
    if deviceIDs.contains(defaultID) {
      return defaultID
    }

    // System default is stale (points at a disconnected device). Fall back to a
    // known input device reported by AVFoundation rather than letting the engine
    // bind to the dead default.
    NSLog(
      "AudioCaptureSession: system default \(defaultID) is no longer present, falling back"
    )
    let fallbackUID = MicrophoneEnumerator.availableDevices().first?.id
    if let fallbackUID,
      let fallbackID = deviceIDs.first(where: { deviceUID(for: $0) == fallbackUID })
    {
      return fallbackID
    }

    throw AudioCaptureError.deviceNotFound
  }

  private func currentDeviceIDs() throws -> [AudioDeviceID] {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDevices,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )

    var size: UInt32 = 0
    var status = AudioObjectGetPropertyDataSize(
      AudioObjectID(kAudioObjectSystemObject),
      &address,
      0,
      nil,
      &size
    )
    guard status == noErr else {
      throw AudioCaptureError.deviceNotFound
    }

    let count = Int(size) / MemoryLayout<AudioDeviceID>.size
    var ids = [AudioDeviceID](repeating: 0, count: count)
    status = AudioObjectGetPropertyData(
      AudioObjectID(kAudioObjectSystemObject),
      &address,
      0,
      nil,
      &size,
      &ids
    )
    guard status == noErr else {
      throw AudioCaptureError.deviceNotFound
    }
    return ids
  }

  private func currentDefaultInputDeviceID() throws -> AudioDeviceID {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDefaultInputDevice,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )

    var id = AudioDeviceID(0)
    var size = UInt32(MemoryLayout<AudioDeviceID>.size)
    let status = AudioObjectGetPropertyData(
      AudioObjectID(kAudioObjectSystemObject),
      &address,
      0,
      nil,
      &size,
      &id
    )
    guard status == noErr else {
      throw AudioCaptureError.deviceNotFound
    }
    return id
  }

  private func setDefaultInputDevice(id: AudioDeviceID) throws {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDefaultInputDevice,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )

    var mutableID = id
    let size = UInt32(MemoryLayout<AudioDeviceID>.size)
    let status = AudioObjectSetPropertyData(
      AudioObjectID(kAudioObjectSystemObject),
      &address,
      0,
      nil,
      size,
      &mutableID
    )
    guard status == noErr else {
      NSLog("AudioCaptureSession: setDefaultInputDevice id=\(id) failed status=\(status)")
      throw AudioCaptureError.deviceNotFound
    }
    NSLog("AudioCaptureSession: setDefaultInputDevice id=\(id) ok")
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

  /// Device name for diagnostics (falls back to the UID or ID).
  private func deviceName(for deviceID: AudioDeviceID) -> String {
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
    return deviceUID(for: deviceID) ?? "\(deviceID)"
  }

  /// Nominal sample rate of the device (global), if readable.
  private func nominalSampleRate(for deviceID: AudioDeviceID) -> Double? {
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

  /// Actual input stream format (sample rate + channels) of element 0 on the
  /// input scope. This is what the hardware will really deliver — useful to
  /// compare against AVAudioEngine's reported `outputFormat(forBus: 0)`.
  private func inputStreamDescription(for deviceID: AudioDeviceID) -> (
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

  private func logDeviceDescription(id: AudioDeviceID, label: String) {
    let uid = deviceUID(for: id) ?? "n/a"
    let name = deviceName(for: id)
    let nominal = nominalSampleRate(for: id).map { "\($0) Hz" } ?? "n/a"
    let stream =
      inputStreamDescription(for: id).map { "\($0.sampleRate) Hz / \($0.channels) ch" } ?? "n/a"
    NSLog(
      """
      AudioCaptureSession: \(label) device id=\(id) name=\"\(name)\" \
      uid=\(uid) nominal=\(nominal) inputStream=\(stream)
      """
    )
  }

  private func logAllDevices() {
    guard let ids = try? currentDeviceIDs() else {
      NSLog("AudioCaptureSession: failed to enumerate devices")
      return
    }
    NSLog("AudioCaptureSession: present devices count=\(ids.count)")
    for id in ids {
      logDeviceDescription(id: id, label: "  device")
    }
  }

  private func waitForFirstInputBuffer(_ gate: FirstAudioBufferGate) async throws {
    try await gate.wait(timeout: .seconds(1))
  }

  private nonisolated static func makeGatedTapHandler(
    firstBufferGate: FirstAudioBufferGate,
    tapHandler: @escaping AVAudioNodeTapBlock
  ) -> AVAudioNodeTapBlock {
    { buffer, time in
      firstBufferGate.signalIfNeeded(buffer: buffer)
      tapHandler(buffer, time)
    }
  }
}
