import SwiftUI

struct MenuBarView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text(appModel.state.menuBarTitle)
            .font(.headline)

        if appModel.state == .loading, let fraction = appModel.assetDownloadFraction {
            Text("Downloading Apple Speech assets… \(Int(fraction * 100))%")
                .font(.caption)
                .foregroundStyle(.secondary)
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
        .disabled(appModel.state == .loading || appModel.state == .processing)

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
            ForEach(RecognitionLanguageOption.allCases) { language in
                Button {
                    appModel.configStore.update { $0.language = language }
                    Task {
                        await appModel.applyLanguageConfiguration()
                    }
                } label: {
                    if appModel.configStore.configuration.language == language {
                        Label(language.label, systemImage: "checkmark")
                    } else {
                        Text(language.label)
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

        Menu("Recognition Engine") {
            ForEach(RecognitionEngineOption.allCases) { engine in
                Button {
                    appModel.configStore.update { $0.recognitionEngine = engine }
                } label: {
                    if appModel.configStore.configuration.recognitionEngine == engine {
                        Label(engine.label, systemImage: "checkmark")
                    } else {
                        Text(engine.label)
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

        let result = await appModel.prepareForRecording()
        switch result {
        case .ready:
            await appModel.startRecording()
        case .blocked:
            openWindow(id: "permissionDoctor")
        }
    }
}

#Preview {
    MenuBarView()
        .environment(AppModel())
}
