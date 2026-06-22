import AppKit
import Foundation

struct ClipboardBackup: Sendable {
    let text: String?
    let changeCountBeforeWrite: Int

    static func capture(from pasteboard: NSPasteboard = .general) -> ClipboardBackup {
        ClipboardBackup(
            text: pasteboard.string(forType: .string),
            changeCountBeforeWrite: pasteboard.changeCount
        )
    }

    func restoreIfNeeded(
        to pasteboard: NSPasteboard,
        changeCountAfterWrite: Int,
        restoreEnabled: Bool
    ) {
        guard restoreEnabled else {
            return
        }

        guard pasteboard.changeCount == changeCountAfterWrite else {
            return
        }

        pasteboard.clearContents()
        if let text {
            pasteboard.setString(text, forType: .string)
        }
    }
}
