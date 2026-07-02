import AVFoundation
import AudioToolbox
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
  /// How long to wait for the first non-empty tap buffer before treating capture
  /// as failed to start.
  private static let firstBufferTimeout: Duration = .seconds(1)

  /// Delay before the single internal retry after a stale-format / engine-start
  /// failure. Gives CoreAudio a moment to settle after a device change.
  private static let retryDelay: Duration = .milliseconds(150)

  /// After binding a device, the input node's format can take a brief moment to
  /// reflect the new device (CoreAudio renegotiates asynchronously). Poll for it
  /// to settle instead of immediately failing into the much more expensive
  /// engine-recreate retry path — this is the common case, not an error case.
  private static let formatSettleAttempts = 15
  private static let formatSettlePollInterval: Duration = .milliseconds(20)

  private static let tapBufferSize: AVAudioFrameCount = 1024

  private let deviceDirectory: AudioDeviceDirectory

  // Only recreated when the resolved device actually changes (see `attemptStart`).
  // Recreating on every single start — even when repeating with the same device —
  // was found to race with CoreAudio's own async teardown of the previous engine's
  // HAL I/O thread (and, for devices CoreAudio wraps in an on-demand aggregate,
  // that aggregate's teardown/rebuild). Starting a new engine before that settles
  // fails with HAL errors like "there already is a thread" and a bogus fallback
  // format, which surfaces to the user as "Microphone input did not become
  // active." Recreating is still necessary when the device itself changes, to
  // avoid the stale-output-format crash this was originally introduced to fix.
  private var engine = AVAudioEngine()
  private var isCapturing = false
  private var boundResolution: ResolvedInputDevice?

  var inputFormat: AVAudioFormat {
    engine.inputNode.outputFormat(forBus: 0)
  }

  init(deviceDirectory: AudioDeviceDirectory = CoreAudioDeviceDirectory()) {
    self.deviceDirectory = deviceDirectory
    registerDefaultDeviceChangeListener()
  }

  /// The system default input device can change without any device actually
  /// connecting/disconnecting (e.g. the user picks a different mic in System
  /// Settings, or CoreAudio silently swaps an on-demand aggregate device).
  /// `resolveInputDevice` alone can't see that between calls, so listen for it
  /// directly and drop the cached binding — the next `start()` will resolve and
  /// bind fresh instead of assuming the old engine is still pointing the right way.
  private func registerDefaultDeviceChangeListener() {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDefaultInputDevice,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )

    AudioObjectAddPropertyListenerBlock(
      AudioObjectID(kAudioObjectSystemObject), &address, DispatchQueue.main
    ) { [weak self] _, _ in
      Task { @MainActor in
        self?.invalidateBoundResolution()
      }
    }
  }

  private func invalidateBoundResolution() {
    guard boundResolution != nil else {
      return
    }
    AudioCaptureDiagnostics.logDefaultDeviceChanged()
    boundResolution = nil
  }

  /// Starts capturing from `deviceUID` (or the system default input when `nil`).
  ///
  /// Device selection is scoped to this app's own `AVAudioEngine` instance via
  /// `AUAudioUnit.setDeviceID` — this never touches the system-wide default input
  /// device, so other apps' audio input is never affected.
  func start(deviceUID: String?, tapHandler: @escaping AVAudioNodeTapBlock) async throws {
    guard !isCapturing else {
      return
    }

    let clock = ContinuousClock()
    let overallStart = clock.now
    AudioCaptureDiagnostics.logStartRequested(deviceUID: deviceUID)

    do {
      try await attemptStart(deviceUID: deviceUID, tapHandler: tapHandler, forceRebind: false)
      AudioCaptureDiagnostics.logDuration("start (total)", clock.now - overallStart)
    } catch {
      // Full device dump is diagnostics-only and not cheap (several CoreAudio
      // calls per device) — only pay for it once something has actually gone
      // wrong, not on every normal start.
      AudioCaptureDiagnostics.logAllDevices(directory: deviceDirectory)

      guard isRetryableAfterEngineRefresh(error) else {
        throw error
      }

      // Something already went wrong with the current engine/binding — always
      // rebuild from scratch on the retry rather than trusting the cached bind.
      AudioCaptureDiagnostics.logRetrying(after: error)
      try await Task.sleep(for: Self.retryDelay)
      try await attemptStart(deviceUID: deviceUID, tapHandler: tapHandler, forceRebind: true)
      AudioCaptureDiagnostics.logDuration("start (total, after retry)", clock.now - overallStart)
    }
  }

  func stop() {
    guard isCapturing else {
      return
    }

    engine.inputNode.removeTap(onBus: 0)
    engine.stop()
    isCapturing = false
  }

  /// A stale-format or transient engine-start failure can usually be resolved by
  /// recreating the engine and trying once more. A missing device is a real,
  /// non-transient condition and is not worth retrying.
  private func isRetryableAfterEngineRefresh(_ error: Error) -> Bool {
    switch error as? AudioCaptureError {
    case .noInputReceived, .engineStartFailed:
      return true
    default:
      return false
    }
  }

  private func attemptStart(
    deviceUID: String?, tapHandler: @escaping AVAudioNodeTapBlock, forceRebind: Bool
  ) async throws {
    let clock = ContinuousClock()
    let attemptStart = clock.now

    let resolution = try resolveInputDevice(deviceUID: deviceUID)
    AudioCaptureDiagnostics.logResolution(resolution, directory: deviceDirectory)
    let resolvedAt = clock.now
    AudioCaptureDiagnostics.logDuration("resolve", resolvedAt - attemptStart)

    if forceRebind || resolution != boundResolution {
      refreshEngine()
      try bindInputDevice(resolution)
      AudioCaptureDiagnostics.logDuration("bind (rebuilt)", clock.now - resolvedAt)
    } else {
      AudioCaptureDiagnostics.logReusingEngine()
    }

    do {
      try await startCapture(deviceUID: deviceUID, tapHandler: tapHandler)
      boundResolution = resolution
    } catch {
      invalidateBoundResolution()
      throw error
    }
  }

  private func refreshEngine() {
    if isCapturing {
      engine.inputNode.removeTap(onBus: 0)
      engine.stop()
    }
    engine = AVAudioEngine()
  }

  /// Binds `engine`'s input node to a specific device, or leaves it untouched so
  /// it keeps following the system default (`.systemDefault`). Must run before the
  /// input node's format is read or a tap is installed.
  private func bindInputDevice(_ resolution: ResolvedInputDevice) throws {
    let deviceID: AudioDeviceID
    switch resolution {
    case .systemDefault:
      return
    case .specific(let id), .fallback(let id):
      deviceID = id
    }

    do {
      try engine.inputNode.auAudioUnit.setDeviceID(AUAudioObjectID(deviceID))
    } catch {
      AudioCaptureDiagnostics.logBindFailure(id: deviceID, error: error)
      throw AudioCaptureError.deviceNotFound
    }
  }

  private func startCapture(
    deviceUID: String?,
    tapHandler: @escaping AVAudioNodeTapBlock
  ) async throws {
    let clock = ContinuousClock()
    let phaseStart = clock.now
    let inputNode = engine.inputNode

    let (format, hardwareInputFormat) = try await settledFormat(for: inputNode)
    AudioCaptureDiagnostics.logDuration("formatSettle", clock.now - phaseStart)
    AudioCaptureDiagnostics.logFormatProbe(
      deviceUID: deviceUID, format: format, hardwareInputFormat: hardwareInputFormat)

    guard isTapFormatValid(format, hardwareInputFormat: hardwareInputFormat) else {
      AudioCaptureDiagnostics.logInvalidFormat(format, hardwareInputFormat: hardwareInputFormat)
      throw AudioCaptureError.engineStartFailed
    }

    let firstBufferGate = FirstAudioBufferGate()
    let gatedTapHandler = Self.makeGatedTapHandler(
      firstBufferGate: firstBufferGate,
      tapHandler: tapHandler
    )
    inputNode.removeTap(onBus: 0)
    inputNode.installTap(
      onBus: 0, bufferSize: Self.tapBufferSize, format: format, block: gatedTapHandler)

    engine.prepare()
    let engineStartBegin = clock.now
    do {
      try engine.start()
    } catch {
      inputNode.removeTap(onBus: 0)
      AudioCaptureDiagnostics.logEngineStartFailed(error)
      throw AudioCaptureError.engineStartFailed
    }
    AudioCaptureDiagnostics.logDuration("engineStart", clock.now - engineStartBegin)

    isCapturing = true

    let firstBufferBegin = clock.now
    do {
      try await waitForFirstInputBuffer(firstBufferGate)
    } catch {
      stop()
      throw error
    }
    AudioCaptureDiagnostics.logDuration("firstBuffer", clock.now - firstBufferBegin)
  }

  /// Polls the input node's format for up to `formatSettleAttempts` short
  /// intervals until input/output sample rates agree, instead of immediately
  /// treating a momentary mismatch (common right after binding a new device) as
  /// a hard failure that would trigger a full, much slower engine-recreate retry.
  private func settledFormat(for inputNode: AVAudioInputNode) async throws -> (
    AVAudioFormat, AVAudioFormat
  ) {
    var format = inputNode.outputFormat(forBus: 0)
    var hardwareInputFormat = inputNode.inputFormat(forBus: 0)

    var attempt = 0
    while !isTapFormatValid(format, hardwareInputFormat: hardwareInputFormat),
      attempt < Self.formatSettleAttempts
    {
      try await Task.sleep(for: Self.formatSettlePollInterval)
      format = inputNode.outputFormat(forBus: 0)
      hardwareInputFormat = inputNode.inputFormat(forBus: 0)
      attempt += 1
    }

    return (format, hardwareInputFormat)
  }

  /// The input node's input and output formats should agree on sample rate for a
  /// tap on the output bus. A mismatch signals a stale format cache and would make
  /// `installTap` throw an uncatchable ObjC exception.
  private func isTapFormatValid(_ format: AVAudioFormat, hardwareInputFormat: AVAudioFormat)
    -> Bool
  {
    guard format.sampleRate > 0, format.channelCount > 0 else {
      return false
    }

    if hardwareInputFormat.sampleRate > 0, hardwareInputFormat.sampleRate != format.sampleRate {
      return false
    }

    return true
  }

  /// Resolves a concrete, currently-present input device for the requested UID.
  /// - When `deviceUID` is provided, requires that device to still be present
  ///   (throws `deviceNotFound` otherwise — surfaces as reload guidance, no crash).
  /// - When `deviceUID` is nil (System Default), verifies the system default is
  ///   still a live device. If macOS left the default pointing at a just
  ///   disconnected device, resolves a fallback device instead — see
  ///   `InputDeviceResolver`.
  private func resolveInputDevice(deviceUID: String?) throws -> ResolvedInputDevice {
    guard let liveDeviceIDs = try? deviceDirectory.liveDeviceIDs() else {
      throw AudioCaptureError.deviceNotFound
    }

    switch InputDeviceResolver.resolve(
      requestedUID: deviceUID,
      liveDeviceIDs: liveDeviceIDs,
      defaultDeviceID: try? deviceDirectory.defaultInputDeviceID(),
      uidLookup: deviceDirectory.uid(for:)
    ) {
    case .success(let resolution):
      return resolution
    case .failure(let error):
      throw error
    }
  }

  private func waitForFirstInputBuffer(_ gate: FirstAudioBufferGate) async throws {
    try await gate.wait(timeout: Self.firstBufferTimeout)
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
