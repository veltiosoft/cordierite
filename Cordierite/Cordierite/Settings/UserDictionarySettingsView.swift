import SwiftUI

struct UserDictionarySettingsView: View {
  @Bindable var store: UserDictionaryStore

  @State private var isPresentingEditor = false
  @State private var editingEntry: UserDictionaryEntry?
  @State private var editorSource = ""
  @State private var editorReplacement = ""
  @State private var editorErrorMessage: String?

  var body: some View {
    Section {
      LabeledContent("Entries") {
        Text("\(store.entryCount) / \(UserDictionaryStore.maxEntryCount)")
          .foregroundStyle(.secondary)
      }

      if store.entries.isEmpty {
        Text("Add words that are often misrecognized so Cordierite can replace them before pasting.")
          .font(.caption)
          .foregroundStyle(.secondary)
      } else {
        ForEach(store.entries) { entry in
          HStack {
            VStack(alignment: .leading, spacing: 2) {
              Text(entry.source)
                .font(.body)
              Text(entry.replacement)
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("Enabled", isOn: enabledBinding(for: entry))
              .labelsHidden()
          }
          .contentShape(Rectangle())
          .onTapGesture {
            presentEditor(for: entry)
          }
          .contextMenu {
            Button("Edit…") {
              presentEditor(for: entry)
            }
            Button("Delete", role: .destructive) {
              store.delete(id: entry.id)
            }
          }
        }
        .onDelete { offsets in
          for index in offsets {
            store.delete(id: store.entries[index].id)
          }
        }
      }

      Button("Add Entry…") {
        presentEditor(for: nil)
      }
      .disabled(!store.canAddEntry)

      if !store.canAddEntry {
        Text("The free plan supports up to \(UserDictionaryStore.maxEntryCount) dictionary entries.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    } header: {
      Text("User Dictionary")
    }
    .sheet(isPresented: $isPresentingEditor) {
      editorSheet
    }
  }

  private var editorSheet: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(editingEntry == nil ? "Add Dictionary Entry" : "Edit Dictionary Entry")
        .font(.headline)

      TextField("Recognized text", text: $editorSource)
        .textFieldStyle(.roundedBorder)

      TextField("Replace with", text: $editorReplacement)
        .textFieldStyle(.roundedBorder)

      if let editorErrorMessage {
        Text(editorErrorMessage)
          .font(.caption)
          .foregroundStyle(.red)
      }

      HStack {
        Spacer()
        Button("Cancel") {
          isPresentingEditor = false
        }
        Button(editingEntry == nil ? "Add" : "Save") {
          saveEditor()
        }
        .keyboardShortcut(.defaultAction)
      }
    }
    .padding(20)
    .frame(minWidth: 360)
  }

  private func enabledBinding(for entry: UserDictionaryEntry) -> Binding<Bool> {
    Binding(
      get: { store.entries.first(where: { $0.id == entry.id })?.isEnabled ?? entry.isEnabled },
      set: { isEnabled in
        guard let current = store.entries.first(where: { $0.id == entry.id }),
          current.isEnabled != isEnabled
        else {
          return
        }
        store.toggleEnabled(id: entry.id)
      }
    )
  }

  private func presentEditor(for entry: UserDictionaryEntry?) {
    editingEntry = entry
    editorSource = entry?.source ?? ""
    editorReplacement = entry?.replacement ?? ""
    editorErrorMessage = nil
    isPresentingEditor = true
  }

  private func saveEditor() {
    editorErrorMessage = nil

    do {
      if var entry = editingEntry {
        entry.source = editorSource
        entry.replacement = editorReplacement
        try store.update(entry)
      } else {
        try store.add(source: editorSource, replacement: editorReplacement)
      }
      isPresentingEditor = false
    } catch {
      editorErrorMessage = error.localizedDescription
    }
  }
}

#Preview {
  Form {
    UserDictionarySettingsView(store: UserDictionaryStore())
  }
  .formStyle(.grouped)
  .padding()
}
