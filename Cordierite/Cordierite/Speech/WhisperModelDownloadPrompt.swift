import AppKit
import Foundation

enum WhisperModelDownloadPrompt {
    @MainActor
    static func confirmDownload(for model: WhisperModelOption) -> Bool {
        let alert = NSAlert()
        alert.messageText = "Download Whisper model?"
        alert.informativeText = """
        Model: \(model.shortLabel)
        File: \(model.filename)
        Size: \(model.approximateDownloadSize)
        Source: huggingface.co/\(model.sourceRepository)

        The model is downloaded once and stored locally for offline use.
        """
        alert.addButton(withTitle: "Download")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .informational
        return alert.runModal() == .alertFirstButtonReturn
    }
}
