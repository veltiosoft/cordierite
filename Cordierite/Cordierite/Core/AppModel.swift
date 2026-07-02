import AppKit
import Foundation

@MainActor
@Observable
final class AppModel {
  var state: AppState = .loading
  private(set) var setupIssues: [SetupIssue] = []
  private(set) var lastRecordingBlock: SetupIssue?
  private(set) var availableMicrophones: [MicrophoneDevice] = []
  private(set) var liveTranscript: String = ""
  private(set) var lastTranscript: String?
  private(set) var assetDownloadFraction: Double?
  private(set) var loadingStatusMessage: String?
  private(set) var permissionStatuses: [PermissionKind: PermissionStatus] = [:]
  private(set) var resolvedSystemSpeechLocale: Locale?
  private(set) var whisperModelIsDownloaded = false
  private(set) var whisperModelIsReady = false
  private(set) var downloadedWhisperModels: Set<WhisperModelOption> = []
  private(set) var whisperDownloadErrorMessage: String?
  private(set) var recordingFeedback: RecordingFeedback?

  var selectedWhisperModel: WhisperModelOption {
    WhisperModelOption.resolved(from: configStore.configuration.whisper.model)
  }

  var whisperModelStatusSummary: String {
    let model = selectedWhisperModel
    if whisperModelIsReady {
      return "\(model.shortLabel) is ready."
    }
    if whisperModelIsDownloaded {
      return "\(model.shortLabel) is downloaded but not loaded."
    }
    return "\(model.shortLabel) is not downloaded. Use Manage Models to download it."
  }

  var canStartRecognition: Bool {
    if configStore.configuration.recognitionEngine == .whisper {
      return whisperModelIsReady
    }
    return true
  }

  var currentRecognitionSelection: RecognitionSelection {
    switch configStore.configuration.recognitionEngine {
    case .appleSpeech:
      .appleSpeech
    case .whisper:
      .whisper(selectedWhisperModel)
    }
  }

  var downloadedWhisperModelsSummary: String {
    let labels =
      availableWhisperModelsForRecognition
      .map(\.engineSelectionLabel)

    if labels.isEmpty {
      return "None"
    }
    return labels.joined(separator: ", ")
  }

  var availableWhisperModelsForRecognition: [WhisperModelOption] {
    WhisperModelOption.allCases.filter { downloadedWhisperModels.contains($0) }
  }

  var availableRecognitionSelections: [RecognitionSelection] {
    [.appleSpeech] + availableWhisperModelsForRecognition.map { .whisper($0) }
  }

  func recognitionOptionLabel(for selection: RecognitionSelection) -> String {
    switch selection {
    case .appleSpeech:
      "Apple Speech"
    case .whisper(let model):
      whisperRecognitionOptionLabel(for: model)
    }
  }

  func whisperRecognitionOptionLabel(for model: WhisperModelOption) -> String {
    "Whisper · \(model.menuLabel)"
  }

  func whisperModelManageLabel(for model: WhisperModelOption) -> String {
    if isWhisperModelDownloaded(model) {
      return "\(model.menuLabel) · Downloaded"
    }
    return model.menuLabel
  }

  func isRecognitionSelectionActive(_ selection: RecognitionSelection) -> Bool {
    currentRecognitionSelection == selection
  }

  func isWhisperModelDownloaded(_ model: WhisperModelOption) -> Bool {
    downloadedWhisperModels.contains(model)
  }

  func applyRecognitionSelection(_ selection: RecognitionSelection) async {
    switch selection {
    case .appleSpeech:
      guard configStore.configuration.recognitionEngine != .appleSpeech else {
        return
      }
      configStore.update { $0.recognitionEngine = .appleSpeech }
      configStore.save()
      await applyRecognitionEngineConfiguration()

    case .whisper(let model):
      guard isWhisperModelDownloaded(model) else {
        return
      }

      let wasWhisper = configStore.configuration.recognitionEngine == .whisper
      let previousModel = selectedWhisperModel

      if wasWhisper && previousModel == model {
        await applyWhisperModelConfiguration()
        return
      }

      configStore.update {
        $0.recognitionEngine = .whisper
        $0.whisper.model = model.rawValue
      }

      if !wasWhisper {
        await applyRecognitionEngineConfiguration()
      }

      await applyWhisperModelConfiguration()
    }
  }

  let configStore = ConfigStore()
  let permissionChecker = PermissionChecker()
  private var speechEngine: any SpeechRecognitionEngine
  private let hotkeyMonitor = HotkeyMonitor()
  private let microphoneAvailabilityMonitor = MicrophoneAvailabilityMonitor()
  private let microphoneSelectionGuard: MicrophoneSelectionGuard
  private let recordingController: RecordingController
  private let pasteController = PasteController()
  private var stopRecordingAfterStart = false
  private var isStartingRecording = false

  init() {
    let engine = SpeechEngineFactory.makeEngine(
      for: configStore.configuration.recognitionEngine,
      whisperConfiguration: configStore.configuration.whisper
    )
    speechEngine = engine
    microphoneSelectionGuard = MicrophoneSelectionGuard(configStore: configStore)
    recordingController = RecordingController(speechEngine: engine)

    recordingController.onMaxDurationReached = { [weak self] in
      await self?.stopRecording()
    }

    recordingController.onRecognitionEvent = { [weak self] _ in
      guard let self else {
        return
      }
      liveTranscript = speechEngine.liveDisplayText
    }

    NotificationCenter.default.addObserver(
      forName: NSApplication.didBecomeActiveNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor in
        self?.refreshPermissionState()
        await self?.refreshWhisperModelStatus()
      }
    }

    microphoneAvailabilityMonitor.start { [weak self] in self?.refreshMicrophoneList() }

    Task {
      await bootstrap()
    }
  }

  func bootstrap() async {
    state = .loading
    refreshMicrophoneList()
    loadingStatusMessage = speechEngine.loadingStatusMessage

    do {
      let progressTask = Task {
        while !Task.isCancelled {
          assetDownloadFraction = speechEngine.downloadProgress?.fractionCompleted
          try? await Task.sleep(for: .milliseconds(100))
        }
      }
      defer { progressTask.cancel() }

      try await speechEngine.prepare(language: configStore.configuration.language)
      assetDownloadFraction = nil
      if configStore.configuration.recognitionEngine == .appleSpeech {
        await refreshResolvedSystemSpeechLocale()
      }
    } catch {
      assetDownloadFraction = nil
      NSLog("Speech engine preparation failed: \(error.localizedDescription)")
    }

    loadingStatusMessage = nil
    await refreshWhisperModelStatus()
    refreshPermissionState()
    reloadHotkeyMonitor()
  }

  func refreshWhisperModelStatus() async {
    whisperDownloadErrorMessage = nil

    let store = WhisperModelStore.shared
    var downloaded = Set<WhisperModelOption>()
    for model in WhisperModelOption.allCases {
      if (try? await store.isDownloaded(modelID: model.rawValue)) == true {
        downloaded.insert(model)
      }
    }
    downloadedWhisperModels = downloaded

    await reconcileRecognitionSelectionIfNeeded()

    guard configStore.configuration.recognitionEngine == .whisper,
      let whisperEngine = speechEngine as? WhisperEngine
    else {
      whisperModelIsDownloaded = false
      whisperModelIsReady = false
      return
    }

    whisperModelIsDownloaded = downloaded.contains(selectedWhisperModel)
    whisperModelIsReady = whisperEngine.isReady
  }

  private func reconcileRecognitionSelectionIfNeeded() async {
    guard configStore.configuration.recognitionEngine == .whisper,
      !isWhisperModelDownloaded(selectedWhisperModel)
    else {
      return
    }

    NSLog("Whisper model is not downloaded; falling back to Apple Speech.")
    configStore.update { $0.recognitionEngine = .appleSpeech }
    configStore.save()
    await applyRecognitionEngineConfiguration()
  }

  func applyWhisperModelConfiguration() async {
    configStore.save()

    guard configStore.configuration.recognitionEngine == .whisper,
      let whisperEngine = speechEngine as? WhisperEngine
    else {
      await refreshWhisperModelStatus()
      return
    }

    whisperEngine.updateConfiguration(configStore.configuration.whisper)

    if await whisperEngine.isSelectedModelDownloaded() {
      loadingStatusMessage = "Loading \(selectedWhisperModel.shortLabel)…"
      state = .loading
      defer {
        loadingStatusMessage = nil
      }
      try? await whisperEngine.prepare(language: configStore.configuration.language)
    }

    await refreshWhisperModelStatus()
    if state != .recording && state != .processing {
      state = setupIssues.isEmpty ? .ready : .needsSetup
    }
  }

  func downloadWhisperModel(_ model: WhisperModelOption) async {
    guard WhisperModelDownloadPrompt.confirmDownload(for: model) else {
      return
    }

    whisperDownloadErrorMessage = nil
    state = .loading
    loadingStatusMessage = "Downloading \(model.shortLabel)…"

    let downloadProgress = Progress()
    let progressTask = Task {
      while !Task.isCancelled {
        let fraction = downloadProgress.fractionCompleted
        assetDownloadFraction = fraction > 0 && fraction < 1 ? fraction : nil
        try? await Task.sleep(for: .milliseconds(100))
      }
    }
    defer {
      progressTask.cancel()
      assetDownloadFraction = nil
      loadingStatusMessage = nil
    }

    do {
      if configStore.configuration.recognitionEngine == .whisper,
        selectedWhisperModel == model,
        let whisperEngine = speechEngine as? WhisperEngine
      {
        try await whisperEngine.downloadSelectedModel(progress: downloadProgress)
      } else {
        _ = try await WhisperModelStore.shared.download(
          modelID: model.rawValue, progress: downloadProgress)
        if configStore.configuration.recognitionEngine == .whisper,
          selectedWhisperModel == model
        {
          await applyWhisperModelConfiguration()
          whisperDownloadErrorMessage = nil
          refreshPermissionState()
          reloadHotkeyMonitor()
          return
        }
      }
      whisperDownloadErrorMessage = nil
    } catch {
      whisperDownloadErrorMessage = error.localizedDescription
      NSLog("Whisper model download failed: \(error.localizedDescription)")
    }

    await refreshWhisperModelStatus()
    refreshPermissionState()
    reloadHotkeyMonitor()
  }

  func deleteWhisperModel(_ model: WhisperModelOption) async {
    guard isWhisperModelDownloaded(model) else {
      return
    }

    guard WhisperModelDeletePrompt.confirmDelete(for: model) else {
      return
    }

    whisperDownloadErrorMessage = nil

    do {
      try await WhisperModelStore.shared.delete(modelID: model.rawValue)

      if configStore.configuration.recognitionEngine == .whisper,
        selectedWhisperModel == model,
        let whisperEngine = speechEngine as? WhisperEngine
      {
        whisperEngine.unloadLoadedModel()
      }
    } catch {
      whisperDownloadErrorMessage = error.localizedDescription
      NSLog("Whisper model delete failed: \(error.localizedDescription)")
    }

    await refreshWhisperModelStatus()
    if state != .recording && state != .processing {
      state = setupIssues.isEmpty ? .ready : .needsSetup
    }
  }

  func refreshPermissionState() {
    permissionStatuses = permissionChecker.snapshot()
    setupIssues = permissionChecker.collectSetupIssues()
    lastRecordingBlock = setupIssues.first

    guard state != .recording && state != .processing && state != .starting else {
      return
    }

    state = setupIssues.isEmpty ? .ready : .needsSetup
    reloadHotkeyMonitor()
  }

  var allPermissionsGranted: Bool {
    permissionChecker.allPermissionsGranted
  }

  func refreshMicrophoneList() {
    availableMicrophones = MicrophoneEnumerator.availableDevices()
    if microphoneSelectionGuard.reconcile(availableMicrophones: availableMicrophones) {
      recordingFeedback = .microphoneResetToSystemDefault
    }
  }

  func reloadHotkeyMonitor() {
    guard setupIssues.isEmpty,
      permissionChecker.status(for: .inputMonitoring) == .granted
    else {
      if state != .recording && state != .processing {
        hotkeyMonitor.stop()
      }
      return
    }

    if hotkeyMonitor.isRunning {
      return
    }

    _ = hotkeyMonitor.start(
      hotkey: configStore.configuration.hotkey,
      inputMode: configStore.configuration.inputMode
    ) { [weak self] action in
      self?.handleHotkey(action)
    }
  }

  func applyInputConfiguration() {
    configStore.save()
    hotkeyMonitor.stop()
    reloadHotkeyMonitor()
  }

  func applyLanguageConfiguration() async {
    configStore.save()
    await reloadSpeechEngine(prepareLanguage: configStore.configuration.language)
  }

  func applyRecognitionEngineConfiguration() async {
    configStore.save()
    await reloadSpeechEngine(prepareLanguage: configStore.configuration.language)
    await refreshWhisperModelStatus()
  }

  func applyWhisperLanguageConfiguration() {
    configStore.save()
    if let whisperEngine = speechEngine as? WhisperEngine {
      whisperEngine.updateConfiguration(configStore.configuration.whisper)
    }
  }

  func languageMenuLabel(for option: RecognitionLanguageOption) -> String {
    RecognitionLanguageResolver.menuLabel(
      for: option,
      resolvedLocale: option == .system ? resolvedSystemSpeechLocale : nil
    )
  }

  private func refreshResolvedSystemSpeechLocale() async {
    resolvedSystemSpeechLocale = await RecognitionLanguageResolver.resolvedLocale(for: .system)
  }

  private func reloadSpeechEngine(prepareLanguage language: RecognitionLanguageOption) async {
    state = .loading
    await speechEngine.shutdown()

    speechEngine = SpeechEngineFactory.makeEngine(
      for: configStore.configuration.recognitionEngine,
      whisperConfiguration: configStore.configuration.whisper
    )
    recordingController.setSpeechEngine(speechEngine)
    await bootstrap()
  }

  func prepareForRecording() async -> RecordingPrepResult {
    var microphoneJustGranted = false

    if permissionChecker.status(for: .microphone) == .notDetermined {
      let granted = await permissionChecker.requestMicrophoneAccess()
      refreshPermissionState()
      if !granted {
        lastRecordingBlock = .microphoneDenied
        return .blocked(.microphoneDenied)
      }
      microphoneJustGranted = true
    }

    refreshPermissionState()

    guard permissionChecker.canStartRecording else {
      if let issue = setupIssues.first {
        lastRecordingBlock = issue
        return .blocked(issue)
      }

      lastRecordingBlock = .microphoneDenied
      return .blocked(.microphoneDenied)
    }

    lastRecordingBlock = nil
    return .ready(microphoneJustGranted: microphoneJustGranted)
  }

  func startRecording() async {
    guard state == .ready || state == .needsSetup || state == .starting else {
      return
    }

    guard !isStartingRecording else {
      return
    }

    guard canStartRecognition else {
      recordingFeedback = .whisperModelNotReady
      NSLog("Recording blocked: Whisper model is not ready.")
      return
    }

    if state != .starting {
      state = .starting
    }

    isStartingRecording = true
    defer {
      isStartingRecording = false
    }

    await recoverOrphanedRecordingIfNeeded()

    let preparation = await prepareForRecording()
    guard case .ready(let microphoneJustGranted) = preparation else {
      stopRecordingAfterStart = false
      if case .blocked(let issue) = preparation {
        recordingFeedback = .blocked(by: issue)
      }
      restoreIdleState()
      return
    }

    recordingFeedback = nil
    liveTranscript = ""

    do {
      try await recordingController.start(
        deviceUID: configStore.configuration.microphoneDeviceID,
        maxRecordingSeconds: configStore.configuration.maxRecordingSeconds,
        language: configStore.configuration.language,
        retryAudioCapture: microphoneJustGranted
      )
      state = .recording

      if stopRecordingAfterStart {
        stopRecordingAfterStart = false
        await stopRecording()
      }
    } catch {
      stopRecordingAfterStart = false
      await recoverOrphanedRecordingIfNeeded()
      handleRecordingStartFailure(error)
      restoreIdleState()
      NSLog("Failed to start recording: \(error.localizedDescription)")
    }
  }

  private func handleRecordingStartFailure(_ error: Error) {
    if case AudioCaptureError.deviceNotFound = error,
      configStore.configuration.microphoneDeviceID != nil
    {
      microphoneSelectionGuard.reset()
      refreshMicrophoneList()
      recordingFeedback = .microphoneResetToSystemDefault
      return
    }
    recordingFeedback = .startFailed(error)
  }

  private func restoreIdleState() {
    guard state != .recording && state != .processing else {
      return
    }
    state = setupIssues.isEmpty ? .ready : .needsSetup
  }

  private func recoverOrphanedRecordingIfNeeded() async {
    guard recordingController.isRecording, state != .recording, state != .processing else {
      return
    }

    NSLog("Recovering orphaned recording session.")
    _ = await recordingController.stop()
  }

  func stopRecording() async {
    if state == .ready || state == .starting {
      stopRecordingAfterStart = true
      return
    }

    guard state == .recording else {
      return
    }

    state = .processing
    let result = await recordingController.stop()

    switch result {
    case .accepted(let duration, let peakRMS, let transcript):
      let processedTranscript = TextPostProcessor.process(
        transcript,
        removeFillerWords: configStore.configuration.removeFillerWords
      )

      guard !processedTranscript.isEmpty else {
        liveTranscript = ""
        recordingFeedback = .textRemovedByCleanup
        NSLog("Recording discarded after post-processing: \(duration)s, peak RMS \(peakRMS)")
        state = .ready
        reloadHotkeyMonitor()
        return
      }

      lastTranscript = processedTranscript
      liveTranscript = processedTranscript
      NSLog("Transcript (\(duration)s, peak RMS \(peakRMS)): \(processedTranscript)")

      do {
        try await pasteController.paste(
          text: processedTranscript,
          method: configStore.configuration.pasteMethod,
          restoreClipboard: configStore.configuration.restoreClipboardText
        )
      } catch {
        NSLog("Paste failed: \(error.localizedDescription)")
        if case PasteError.accessibilityNotGranted = error {
          refreshPermissionState()
        }
      }

      recordingFeedback = nil
      state = .ready
      reloadHotkeyMonitor()
    case .discardedSilence(let duration, let peakRMS):
      liveTranscript = ""
      recordingFeedback = .silenceDiscarded
      NSLog("Recording discarded: \(duration)s, peak RMS \(peakRMS)")
      state = .ready
      reloadHotkeyMonitor()
    case .failed(let message):
      liveTranscript = ""
      recordingFeedback = .recognitionFailed
      NSLog("Recording failed: \(message)")
      state = .ready
      reloadHotkeyMonitor()
    }
  }

  func toggleRecording() async {
    if state == .recording {
      await stopRecording()
    } else {
      await startRecording()
    }
  }

  private func handleHotkey(_ action: HotkeyAction) {
    Task {
      switch configStore.configuration.inputMode {
      case .hold:
        switch action {
        case .press:
          stopRecordingAfterStart = false
          await startRecording()
        case .release:
          await stopRecording()
        }
      case .toggle:
        guard action == .press else {
          return
        }
        await toggleRecording()
      }
    }
  }

  func openPermissionSettings(for kind: PermissionKind) {
    permissionChecker.openSystemSettings(for: kind)
  }

  func requestPermission(for kind: PermissionKind) {
    switch kind {
    case .microphone:
      Task {
        _ = await permissionChecker.requestMicrophoneAccess()
        refreshPermissionState()
      }
    case .inputMonitoring:
      _ = permissionChecker.requestInputMonitoringAccess()
      refreshPermissionState()
    case .accessibility:
      _ = permissionChecker.promptForAccessibilityAccess()
      refreshPermissionState()
    }
  }

  func quit() {
    hotkeyMonitor.stop()
    microphoneAvailabilityMonitor.stop()
    Task {
      if recordingController.isRecording {
        _ = await recordingController.stop()
      }
      await speechEngine.shutdown()
      NSApplication.shared.terminate(nil)
    }
  }
}
