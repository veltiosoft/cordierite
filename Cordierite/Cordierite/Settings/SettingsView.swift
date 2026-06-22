import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        let configStore = appModel.configStore

        TabView {
            Form {
                Section("Input") {
                    Picker("Input Mode", selection: configStore.binding(\.inputMode)) {
                        ForEach(InputMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .onChange(of: configStore.configuration.inputMode) { _, _ in
                        appModel.applyInputConfiguration()
                    }

                    Picker("Hotkey", selection: configStore.binding(\.hotkey)) {
                        ForEach(HotkeyOption.allCases) { hotkey in
                            Text(hotkey.label).tag(hotkey)
                        }
                    }
                    .onChange(of: configStore.configuration.hotkey) { _, _ in
                        appModel.applyInputConfiguration()
                    }

                    Picker("Language", selection: configStore.binding(\.language)) {
                        ForEach(RecognitionLanguageOption.allCases) { language in
                            Text(language.label).tag(language)
                        }
                    }
                    .onChange(of: configStore.configuration.language) { _, _ in
                        Task {
                            await appModel.applyLanguageConfiguration()
                        }
                    }

                    Picker("Microphone", selection: microphoneSelection) {
                        Text("System Default").tag(Optional<String>.none)
                        ForEach(appModel.availableMicrophones) { device in
                            Text(device.name).tag(Optional(device.id))
                        }
                    }
                }

                Section("Recognition") {
                    Picker("Engine", selection: configStore.binding(\.recognitionEngine)) {
                        ForEach(RecognitionEngineOption.allCases) { engine in
                            Text(engine.label).tag(engine)
                        }
                    }

                    Picker("Paste Method", selection: configStore.binding(\.pasteMethod)) {
                        ForEach(PasteMethodOption.allCases) { method in
                            Text(method.label).tag(method)
                        }
                    }
                }

                Section("General") {
                    Stepper(
                        "Max Recording: \(configStore.configuration.maxRecordingSeconds)s",
                        value: configStore.binding(\.maxRecordingSeconds),
                        in: 10...300,
                        step: 10
                    )

                    Toggle("Restore Clipboard Text", isOn: configStore.binding(\.restoreClipboardText))
                }
            }
            .formStyle(.grouped)
            .padding()
            .tabItem {
                Label("General", systemImage: "gearshape")
            }
        }
        .frame(minWidth: 420, minHeight: 360)
    }

    private var microphoneSelection: Binding<String?> {
        Binding(
            get: { appModel.configStore.configuration.microphoneDeviceID },
            set: { newValue in
                appModel.configStore.update { $0.microphoneDeviceID = newValue }
            }
        )
    }
}

#Preview {
    SettingsView()
        .environment(AppModel())
}
