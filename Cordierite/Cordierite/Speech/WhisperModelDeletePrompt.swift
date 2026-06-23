import AppKit
import Foundation

enum WhisperModelDeletePrompt {
    @MainActor
    static func confirmDelete(for model: WhisperModelOption) -> Bool {
        let alert = NSAlert()
        alert.messageText = "Delete Whisper model?"
        alert.informativeText = """
        Model: \(model.shortLabel)
        File: \(model.filename)

        The local copy will be removed from disk. You can download it again from Manage Models.
        """
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        return alert.runModal() == .alertFirstButtonReturn
    }
}
