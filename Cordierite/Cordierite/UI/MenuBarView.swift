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
           !appModel.whisperModelIsReady || appModel.whisperDownloadErrorMessage != nil {
            whisperSetupSection
            Divider()
        }

        if appModel.state == .needsSetup {
            setupBanner
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
        .disabled(appModel.state == .loading || appModel.state == .processing || appModel.state == .starting || !appModel.canStartRecognition)

        Menu("Input Mode") {
            ForEach(InputMode.allCases) { mode in
                Button {
                    appModel.configStore.update { $0.inputMode = mode }
                    appModel.applyInputConfiguration()
                } label: {
                    if appModel.configStore.configuration.inputMode == mode {
                        Label(mode.label, systemImage: "checkmark")
                    } else {
                        Text(mode.label)
                    }
                }
            }
        }

        Menu("Language") {
            if appModel.configStore.configuration.recognitionEngine == .whisper {
                ForEach(WhisperLanguageOption.allCases) { language in
                    Button {
                        appModel.configStore.update { $0.whisper.language = language }
                        appModel.applyWhisperLanguageConfiguration()
                    } label: {
                        if appModel.configStore.configuration.whisper.language == language {
                            Label(language.label, systemImage: "checkmark")
                        } else {
                            Text(language.label)
                        }
                    }
                }
            } else {
                ForEach(RecognitionLanguageOption.allCases) { language in
                    Button {
                        appModel.configStore.update { $0.language = language }
                        Task {
                            await appModel.applyLanguageConfiguration()
                        }
                    } label: {
                        if appModel.configStore.configuration.language == language {
                            Label(appModel.languageMenuLabel(for: language), systemImage: "checkmark")
                        } else {
                            Text(appModel.languageMenuLabel(for: language))
                        }
                    }
                }
            }
        }

        Menu("Microphone") {
            Button {
                appModel.configStore.update { $0.microphoneDeviceID = nil }
            } label: {
                if appModel.configStore.configuration.microphoneDeviceID == nil {
                    Label("System Default", systemImage: "checkmark")
                } else {
                    Text("System Default")
                }
            }

            if !appModel.availableMicrophones.isEmpty {
                Divider()
            }

            ForEach(appModel.availableMicrophones) { device in
                Button {
                    appModel.configStore.update { $0.microphoneDeviceID = device.id }
                } label: {
                    if appModel.configStore.configuration.microphoneDeviceID == device.id {
                        Label(device.name, systemImage: "checkmark")
                    } else {
                        Text(device.name)
                    }
                }
            }

            Divider()

            Button("Reload Devices") {
                appModel.refreshMicrophoneList()
            }
        }

        Menu("Hotkey") {
            ForEach(HotkeyOption.allCases) { hotkey in
                Button {
                    appModel.configStore.update { $0.hotkey = hotkey }
                    appModel.applyInputConfiguration()
                } label: {
                    if appModel.configStore.configuration.hotkey == hotkey {
                        Label(hotkey.label, systemImage: "checkmark")
                    } else {
                        Text(hotkey.label)
                    }
                }
            }
        }

        Menu(appModel.recognitionMenuTitle) {
            Button {
                Task {
                    await appModel.applyRecognitionSelection(.appleSpeech)
                }
            } label: {
                recognitionOptionLabel(.appleSpeech)
            }

            Divider()

            ForEach(WhisperModelOption.allCases) { model in
                Button {
                    Task {
                        await appModel.applyRecognitionSelection(.whisper(model))
                    }
                } label: {
                    recognitionOptionLabel(.whisper(model))
                }
            }
        }

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

        Divider()

        Button("Quit") {
            appModel.quit()
        }
        .keyboardShortcut("q", modifiers: [.command])
    }

    @ViewBuilder
    private func recognitionOptionLabel(_ selection: RecognitionSelection) -> some View {
        if appModel.isRecognitionSelectionActive(selection) {
            Label(appModel.recognitionOptionLabel(for: selection), systemImage: "checkmark")
        } else {
            Text(appModel.recognitionOptionLabel(for: selection))
        }
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
