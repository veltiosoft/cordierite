import AppKit
import Carbon.HIToolbox
import Foundation

@MainActor
final class HotkeyMonitor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var hotkey: HotkeyOption = .rightOption
    private var inputMode: InputMode = .hold
    private var isHotkeyDown = false
    private var handler: (@MainActor (HotkeyAction) -> Void)?

    private var retainedBridge: Unmanaged<HotkeyMonitorBridge>?

    var isRunning: Bool {
        eventTap != nil
    }

    func start(
        hotkey: HotkeyOption,
        inputMode: InputMode,
        handler: @escaping @MainActor (HotkeyAction) -> Void
    ) -> Bool {
        stop()

        self.hotkey = hotkey
        self.inputMode = inputMode
        self.handler = handler
        isHotkeyDown = false

        let mask = (
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue)
        )

        let bridgeInstance = HotkeyMonitorBridge(monitor: self)
        retainedBridge = Unmanaged.passRetained(bridgeInstance)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: HotkeyMonitorBridge.callback,
            userInfo: retainedBridge!.toOpaque()
        ) else {
            retainedBridge?.release()
            retainedBridge = nil
            return false
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        handler = nil
        isHotkeyDown = false
        retainedBridge?.release()
        retainedBridge = nil
    }

    fileprivate func handle(
        eventType: CGEventType,
        keyCode: UInt16,
        flags: CGEventFlags,
        autorepeat: Int64
    ) {
        switch inputMode {
        case .hold:
            handleHold(eventType: eventType, keyCode: keyCode, flags: flags)
        case .toggle:
            guard keyCode == HotkeyConfiguration.keyCode(for: hotkey) else {
                return
            }
            handleToggle(eventType: eventType, autorepeat: autorepeat)
        }
    }

    private func handleHold(eventType: CGEventType, keyCode: UInt16, flags: CGEventFlags) {
        let targetKeyCode = HotkeyConfiguration.keyCode(for: hotkey)

        if HotkeyConfiguration.isModifierHotkey(hotkey) {
            guard eventType == .flagsChanged, keyCode == targetKeyCode else {
                return
            }

            let pressed = modifierFlag(for: hotkey).map { flags.contains($0) } ?? false
            updateHoldState(pressed: pressed)
            return
        }

        guard keyCode == targetKeyCode else {
            return
        }

        switch eventType {
        case .keyDown:
            updateHoldState(pressed: true)
        case .keyUp:
            updateHoldState(pressed: false)
        default:
            break
        }
    }

    private func handleToggle(eventType: CGEventType, autorepeat: Int64) {
        guard eventType == .keyDown, autorepeat == 0 else {
            return
        }

        handler?(.press)
    }

    private func updateHoldState(pressed: Bool) {
        if pressed && !isHotkeyDown {
            isHotkeyDown = true
            handler?(.press)
        } else if !pressed && isHotkeyDown {
            isHotkeyDown = false
            handler?(.release)
        }
    }

    private func modifierFlag(for hotkey: HotkeyOption) -> CGEventFlags? {
        switch hotkey {
        case .rightOption:
            .maskAlternate
        case .rightCommand:
            .maskCommand
        case .f13:
            nil
        }
    }
}

private final class HotkeyMonitorBridge: @unchecked Sendable {
    weak var monitor: HotkeyMonitor?

    init(monitor: HotkeyMonitor) {
        self.monitor = monitor
    }

    static let callback: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo else {
            return Unmanaged.passUnretained(event)
        }

        let bridge = Unmanaged<HotkeyMonitorBridge>.fromOpaque(userInfo).takeUnretainedValue()
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags
        let autorepeat = event.getIntegerValueField(.keyboardEventAutorepeat)

        Task { @MainActor in
            bridge.monitor?.handle(
                eventType: type,
                keyCode: keyCode,
                flags: flags,
                autorepeat: autorepeat
            )
        }

        return Unmanaged.passUnretained(event)
    }
}
