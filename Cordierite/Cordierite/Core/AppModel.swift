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
    private(set) var permissionStatuses: [PermissionKind: PermissionStatus] = [:]

    let configStore = ConfigStore()
    let permissionChecker = PermissionChecker()
    private let speechEngine = SpeechAnalyzerEngine()
    private let hotkeyMonitor = HotkeyMonitor()
    private let recordingController: RecordingController
    private let pasteController = PasteController()
    private var stopRecordingAfterStart = false

    init() {
        recordingController = RecordingController(speechEngine: speechEngine)

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
            }
        }

        Task {
            await bootstrap()
        }
    }

    func bootstrap() async {
        state = .loading
        refreshMicrophoneList()

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
        } catch {
            assetDownloadFraction = nil
            NSLog("Speech asset preparation failed: \(error.localizedDescription)")
        }

        refreshPermissionState()
        reloadHotkeyMonitor()
    }

    func refreshPermissionState() {
        permissionStatuses = permissionChecker.snapshot()
        setupIssues = permissionChecker.collectSetupIssues()
        lastRecordingBlock = setupIssues.first

        guard state != .recording && state != .processing else {
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
    }

    func reloadHotkeyMonitor() {
        guard setupIssues.isEmpty,
              permissionChecker.status(for: .inputMonitoring) == .granted else {
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
        state = .loading
        do {
            try await speechEngine.prepare(language: configStore.configuration.language)
        } catch {
            NSLog("Speech asset preparation failed: \(error.localizedDescription)")
        }
        refreshPermissionState()
    }

    func prepareForRecording() async -> RecordingPrepResult {
        if permissionChecker.status(for: .microphone) == .notDetermined {
            let granted = await permissionChecker.requestMicrophoneAccess()
            refreshPermissionState()
            if !granted {
                lastRecordingBlock = .microphoneDenied
                return .blocked(.microphoneDenied)
            }
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
        return .ready
    }

    func startRecording() async {
        guard state == .ready else {
            return
        }

        let preparation = await prepareForRecording()
        guard preparation == .ready else {
            stopRecordingAfterStart = false
            return
        }

        liveTranscript = ""

        do {
            try await recordingController.start(
                deviceUID: configStore.configuration.microphoneDeviceID,
                maxRecordingSeconds: configStore.configuration.maxRecordingSeconds,
                language: configStore.configuration.language
            )
            state = .recording

            if stopRecordingAfterStart {
                stopRecordingAfterStart = false
                await stopRecording()
            }
        } catch {
            stopRecordingAfterStart = false
            NSLog("Failed to start recording: \(error.localizedDescription)")
        }
    }

    func stopRecording() async {
        if state == .ready {
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
            lastTranscript = transcript
            liveTranscript = transcript
            NSLog("Transcript (\(duration)s, peak RMS \(peakRMS)): \(transcript)")

            do {
                try await pasteController.paste(
                    text: transcript,
                    method: configStore.configuration.pasteMethod,
                    restoreClipboard: configStore.configuration.restoreClipboardText
                )
            } catch {
                NSLog("Paste failed: \(error.localizedDescription)")
                if case PasteError.accessibilityNotGranted = error {
                    refreshPermissionState()
                }
            }

            state = .ready
            reloadHotkeyMonitor()
        case .discardedSilence(let duration, let peakRMS):
            liveTranscript = ""
            NSLog("Recording discarded: \(duration)s, peak RMS \(peakRMS)")
            state = .ready
            reloadHotkeyMonitor()
        case .failed(let message):
            liveTranscript = ""
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
        Task {
            if recordingController.isRecording {
                _ = await recordingController.stop()
            }
            await speechEngine.cancelSession()
            NSApplication.shared.terminate(nil)
        }
    }
}
