import AppKit
import AVFoundation
import AVFAudio
import ApplicationServices
import Foundation
import IOKit.hid

enum PermissionKind: String, CaseIterable, Identifiable, Sendable {
    case microphone
    case inputMonitoring
    case accessibility

    var id: String { rawValue }

    var title: String {
        switch self {
        case .microphone:
            "Microphone"
        case .inputMonitoring:
            "Input Monitoring"
        case .accessibility:
            "Accessibility"
        }
    }

    var detail: String {
        switch self {
        case .microphone:
            "Required to capture speech from your microphone."
        case .inputMonitoring:
            "Required to detect global hotkeys while other apps are focused."
        case .accessibility:
            "Required to paste transcribed text with Command V."
        }
    }

    var settingsURL: URL {
        switch self {
        case .microphone:
            URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Microphone")!
        case .inputMonitoring:
            URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ListenEvent")!
        case .accessibility:
            URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility")!
        }
    }
}

enum PermissionStatus: String, Sendable {
    case granted
    case denied
    case notDetermined
    case unknown

    var label: String {
        switch self {
        case .granted:
            "Granted"
        case .denied:
            "Denied"
        case .notDetermined:
            "Not Determined"
        case .unknown:
            "Unknown"
        }
    }

    var isGranted: Bool {
        self == .granted
    }
}

@MainActor
struct PermissionChecker {
    func status(for kind: PermissionKind) -> PermissionStatus {
        switch kind {
        case .microphone:
            microphoneStatus()
        case .inputMonitoring:
            inputMonitoringStatus()
        case .accessibility:
            accessibilityStatus()
        }
    }

    func snapshot() -> [PermissionKind: PermissionStatus] {
        Dictionary(uniqueKeysWithValues: PermissionKind.allCases.map { kind in
            (kind, status(for: kind))
        })
    }

    var allPermissionsGranted: Bool {
        PermissionKind.allCases.allSatisfy { status(for: $0) == .granted }
    }

    func collectSetupIssues() -> [SetupIssue] {
        var issues: [SetupIssue] = []

        switch status(for: .microphone) {
        case .denied:
            issues.append(.microphoneDenied)
        case .notDetermined:
            issues.append(.microphoneRequired)
        default:
            break
        }

        if status(for: .inputMonitoring) != .granted {
            issues.append(.inputMonitoringRequired)
        }

        if status(for: .accessibility) != .granted {
            issues.append(.accessibilityRequired)
        }

        return issues
    }

    var canStartRecording: Bool {
        status(for: .microphone) == .granted &&
            status(for: .inputMonitoring) == .granted &&
            status(for: .accessibility) == .granted
    }

    func requestMicrophoneAccess() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    @discardableResult
    func requestInputMonitoringAccess() -> Bool {
        IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }

    @discardableResult
    func promptForAccessibilityAccess() -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func openSystemSettings(for kind: PermissionKind) {
        NSWorkspace.shared.open(kind.settingsURL)
    }

    private func microphoneStatus() -> PermissionStatus {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            .granted
        case .denied:
            .denied
        case .undetermined:
            .notDetermined
        @unknown default:
            .unknown
        }
    }

    private func inputMonitoringStatus() -> PermissionStatus {
        switch IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) {
        case kIOHIDAccessTypeGranted:
            .granted
        case kIOHIDAccessTypeDenied:
            .denied
        case kIOHIDAccessTypeUnknown:
            .notDetermined
        default:
            .unknown
        }
    }

    private func accessibilityStatus() -> PermissionStatus {
        AXIsProcessTrusted() ? .granted : .denied
    }
}
