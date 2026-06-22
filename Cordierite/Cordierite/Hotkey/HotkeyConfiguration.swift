import Carbon.HIToolbox
import Foundation

enum HotkeyConfiguration {
    static func keyCode(for hotkey: HotkeyOption) -> UInt16 {
        switch hotkey {
        case .rightOption:
            UInt16(kVK_RightOption)
        case .rightCommand:
            UInt16(kVK_RightCommand)
        case .f13:
            UInt16(kVK_F13)
        }
    }

    static func isModifierHotkey(_ hotkey: HotkeyOption) -> Bool {
        switch hotkey {
        case .rightOption, .rightCommand:
            true
        case .f13:
            false
        }
    }
}

enum HotkeyAction: Sendable {
    case press
    case release
}
