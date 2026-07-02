import SwiftUI

struct SettingsView: View {
  @Environment(AppModel.self) private var appModel
  @Environment(\.openWindow) private var openWindow

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

          if configStore.configuration.recognitionEngine == .whisper {
            Picker("Language", selection: configStore.binding(\.whisper.language)) {
              ForEach(WhisperLanguageOption.allCases) { language in
                Text(language.label).tag(language)
              }
            }
            .onChange(of: configStore.configuration.whisper.language) { _, _ in
              appModel.applyWhisperLanguageConfiguration()
            }
          } else {
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
          }

          Picker("Microphone", selection: microphoneSelection) {
            Text("System Default").tag(Optional<String>.none)
            ForEach(appModel.availableMicrophones) { device in
              Text(device.name).tag(Optional(device.id))
            }
          }
        }

        Section("Recognition") {
          Picker("Recognition", selection: recognitionSelectionBinding) {
            ForEach(appModel.availableRecognitionSelections) { selection in
              Text(appModel.recognitionOptionLabel(for: selection)).tag(selection)
            }
          }

          if configStore.configuration.recognitionEngine == .whisper {
            LabeledContent("Status") {
              Text(appModel.whisperModelStatusSummary)
                .foregroundStyle(.secondary)
            }

            if let error = appModel.whisperDownloadErrorMessage {
              Text(error)
                .font(.caption)
                .foregroundStyle(.red)
            }
          }

          Picker("Paste Method", selection: configStore.binding(\.pasteMethod)) {
            ForEach(PasteMethodOption.allCases) { method in
              Text(method.label).tag(method)
            }
          }
        }

        Section("Manage Models") {
          ForEach(WhisperModelOption.allCases) { model in
            LabeledContent(appModel.whisperModelManageLabel(for: model)) {
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

        UserDictionarySettingsView(store: appModel.userDictionaryStore)

        Section("General") {
          Stepper(
            "Max Recording: \(configStore.configuration.maxRecordingSeconds)s",
            value: configStore.binding(\.maxRecordingSeconds),
            in: 10...300,
            step: 10
          )

          Toggle("Restore Clipboard Text", isOn: configStore.binding(\.restoreClipboardText))

          Toggle("Remove Filler Words", isOn: configStore.binding(\.removeFillerWords))
        }

        Section("About") {
          LabeledContent("Copyright") {
            Text("© 2026 Veltiosoft Inc.")
              .foregroundStyle(.secondary)
          }

          Button("Acknowledgements…") {
            openWindow(id: "acknowledgements")
          }
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
}

#Preview {
  SettingsView()
    .environment(AppModel())
}
