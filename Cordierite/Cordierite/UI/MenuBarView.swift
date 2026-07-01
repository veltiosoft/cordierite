import SwiftUI

struct MenuBarView: View {
  @Environment(AppModel.self) private var appModel
  @Environment(\.openWindow) private var openWindow

  var body: some View {
    Text(appModel.state.menuBarTitle)
      .font(.headline)

    if appModel.state == .loading {
      if let message = appModel.loadingStatusMessage {
        if let fraction = appModel.assetDownloadFraction, fraction > 0, fraction < 1 {
          Text("\(message) \(Int(fraction * 100))%")
            .font(.caption)
            .foregroundStyle(.secondary)
        } else {
          Text(message)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Divider()
      }
    }

    if appModel.configStore.configuration.recognitionEngine == .whisper,
      !appModel.whisperModelIsReady || appModel.whisperDownloadErrorMessage != nil
    {
      whisperSetupSection
      Divider()
    }

    if appModel.state == .needsSetup {
      setupBanner
      Divider()
    }

    if let feedback = appModel.recordingFeedback, shouldShowRecordingFeedbackBanner(feedback) {
      recordingFeedbackBanner(feedback)
      Divider()
    }

    if appModel.state == .recording, !appModel.liveTranscript.isEmpty {
      Text(appModel.liveTranscript)
        .font(.caption)
        .lineLimit(3)
        .foregroundStyle(.secondary)
      Divider()
    }

    Button(appModel.state == .recording ? "Stop Recording" : "Start Recording") {
      Task {
        await handleRecordingButton()
      }
    }
    .disabled(
      appModel.state == .loading || appModel.state == .processing || appModel.state == .starting
        || !appModel.canStartRecognition)

    Picker("Input Mode", selection: appModel.configStore.binding(\.inputMode)) {
      ForEach(InputMode.allCases) { mode in
        Text(mode.label).tag(mode)
      }
    }
    .pickerStyle(.inline)
    .onChange(of: appModel.configStore.configuration.inputMode) { _, _ in
      appModel.applyInputConfiguration()
    }

    if appModel.configStore.configuration.recognitionEngine == .whisper {
      Picker("Language", selection: appModel.configStore.binding(\.whisper.language)) {
        ForEach(WhisperLanguageOption.allCases) { language in
          Text(language.label).tag(language)
        }
      }
      .pickerStyle(.inline)
      .onChange(of: appModel.configStore.configuration.whisper.language) { _, _ in
        appModel.applyWhisperLanguageConfiguration()
      }
    } else {
      Picker("Language", selection: appModel.configStore.binding(\.language)) {
        ForEach(RecognitionLanguageOption.allCases) { language in
          Text(appModel.languageMenuLabel(for: language)).tag(language)
        }
      }
      .pickerStyle(.inline)
      .onChange(of: appModel.configStore.configuration.language) { _, _ in
        Task {
          await appModel.applyLanguageConfiguration()
        }
      }
    }

    Picker("Microphone", selection: microphoneSelection) {
      Text("System Default").tag(Optional<String>.none)
      ForEach(appModel.availableMicrophones) { device in
        Text(device.name).tag(Optional(device.id))
      }
    }
    .pickerStyle(.inline)

    Button("Reload Devices") {
      appModel.refreshMicrophoneList()
    }

    Picker("Hotkey", selection: appModel.configStore.binding(\.hotkey)) {
      ForEach(HotkeyOption.allCases) { hotkey in
        Text(hotkey.label).tag(hotkey)
      }
    }
    .pickerStyle(.inline)
    .onChange(of: appModel.configStore.configuration.hotkey) { _, _ in
      appModel.applyInputConfiguration()
    }

    Picker("Recognition", selection: recognitionSelectionBinding) {
      ForEach(appModel.availableRecognitionSelections) { selection in
        Text(appModel.recognitionOptionLabel(for: selection)).tag(selection)
      }
    }
    .pickerStyle(.inline)

    Menu("Manage Models") {
      ForEach(WhisperModelOption.allCases) { model in
        Menu(appModel.whisperModelManageLabel(for: model)) {
          if appModel.isWhisperModelDownloaded(model) {
            Button("Delete…") {
              Task {
                await appModel.deleteWhisperModel(model)
              }
            }
          } else {
            Button("Download…") {
              Task {
                await appModel.downloadWhisperModel(model)
              }
            }
          }
        }
      }
    }

    Divider()

    Button("Permission Doctor…") {
      openWindow(id: "permissionDoctor")
    }

    SettingsLink {
      Text("Open Settings…")
    }

    Button("Acknowledgements…") {
      openWindow(id: "acknowledgements")
    }

    Divider()

    Button("Quit") {
      appModel.quit()
    }
    .keyboardShortcut("q", modifiers: [.command])
  }

  private var microphoneSelection: Binding<String?> {
    Binding(
      get: { appModel.configStore.configuration.microphoneDeviceID },
      set: { newValue in
        appModel.configStore.update { $0.microphoneDeviceID = newValue }
      }
    )
  }

  private var recognitionSelectionBinding: Binding<RecognitionSelection> {
    Binding(
      get: { appModel.currentRecognitionSelection },
      set: { newValue in
        Task {
          await appModel.applyRecognitionSelection(newValue)
        }
      }
    )
  }

  @ViewBuilder
  private var whisperSetupSection: some View {
    VStack(alignment: .leading, spacing: 6) {
      if !appModel.whisperModelIsReady {
        Text(appModel.whisperModelStatusSummary)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      if let error = appModel.whisperDownloadErrorMessage {
        Text(error)
          .font(.caption)
          .foregroundStyle(.red)
      }
    }
  }

  @ViewBuilder
  private func recordingFeedbackBanner(_ feedback: RecordingFeedback) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(feedback.title)
        .font(.caption)
        .foregroundStyle(.red)

      if let message = feedback.message {
        Text(message)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      switch feedback.action {
      case .openPermissionDoctor:
        Button("Fix in Permission Doctor…") {
          openWindow(id: "permissionDoctor")
        }
      case .reloadMicrophones:
        Button("Reload Devices") {
          appModel.refreshMicrophoneList()
        }
      case nil:
        EmptyView()
      }
    }
  }

  @ViewBuilder
  private var setupBanner: some View {
    VStack(alignment: .leading, spacing: 6) {
      if let issue = appModel.setupIssues.first {
        Text(issue.message)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Button("Fix in Permission Doctor…") {
        openWindow(id: "permissionDoctor")
      }
    }
  }

  private func shouldShowRecordingFeedbackBanner(_ feedback: RecordingFeedback) -> Bool {
    if appModel.state == .needsSetup, feedback.action == .openPermissionDoctor {
      return false
    }
    return true
  }

  private func handleRecordingButton() async {
    if appModel.state == .recording {
      await appModel.stopRecording()
      return
    }

    await appModel.startRecording()
  }
}

#Preview {
  MenuBarView()
    .environment(AppModel())
}
