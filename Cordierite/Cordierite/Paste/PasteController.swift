import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Foundation

enum PasteError: LocalizedError {
    case accessibilityNotGranted
    case pasteboardWriteFailed
    case unsupportedPasteMethod

    var errorDescription: String? {
        switch self {
        case .accessibilityNotGranted:
            "Enable Accessibility to paste text."
        case .pasteboardWriteFailed:
            "Could not write text to the clipboard."
        case .unsupportedPasteMethod:
            "The selected paste method is not supported."
        }
    }
}

@MainActor
final class PasteController {
    func paste(
        text: String,
        method: PasteMethodOption,
        restoreClipboard: Bool
    ) async throws {
        guard method == .pasteboardCommandV else {
            throw PasteError.unsupportedPasteMethod
        }

        guard AXIsProcessTrusted() else {
            throw PasteError.accessibilityNotGranted
        }

        let pasteboard = NSPasteboard.general
        let backup = ClipboardBackup.capture(from: pasteboard)

        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else {
            throw PasteError.pasteboardWriteFailed
        }

        let changeCountAfterWrite = pasteboard.changeCount
        postCommandV()

        try await Task.sleep(for: .milliseconds(120))

        backup.restoreIfNeeded(
            to: pasteboard,
            changeCountAfterWrite: changeCountAfterWrite,
            restoreEnabled: restoreClipboard
        )
    }

    private func postCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(
            keyboardEventSource: source,
            virtualKey: CGKeyCode(kVK_ANSI_V),
            keyDown: true
        )
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cgSessionEventTap)

        let keyUp = CGEvent(
            keyboardEventSource: source,
            virtualKey: CGKeyCode(kVK_ANSI_V),
            keyDown: false
        )
        keyUp?.flags = .maskCommand
        keyUp?.post(tap: .cgSessionEventTap)
    }
}
