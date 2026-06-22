import Foundation

enum SetupIssue: Identifiable, Equatable, Sendable {
    case microphoneDenied
    case inputMonitoringRequired
    case accessibilityRequired

    var id: String {
        switch self {
        case .microphoneDenied:
            "microphoneDenied"
        case .inputMonitoringRequired:
            "inputMonitoringRequired"
        case .accessibilityRequired:
            "accessibilityRequired"
        }
    }

    var message: String {
        switch self {
        case .microphoneDenied:
            "Microphone permission is required"
        case .inputMonitoringRequired:
            "Enable Input Monitoring for hotkeys"
        case .accessibilityRequired:
            "Enable Accessibility to paste text"
        }
    }

    var guidance: String {
        switch self {
        case .microphoneDenied:
            "Allow microphone access in System Settings, or click Request Access if prompted."
        case .inputMonitoringRequired:
            "Grant Input Monitoring so Cordierite can detect global hotkeys."
        case .accessibilityRequired:
            "Grant Accessibility so Cordierite can paste transcribed text with Command V."
        }
    }

    var permissionKind: PermissionKind {
        switch self {
        case .microphoneDenied:
            .microphone
        case .inputMonitoringRequired:
            .inputMonitoring
        case .accessibilityRequired:
            .accessibility
        }
    }

    var blocksReadyState: Bool {
        true
    }
}

enum RecordingPrepResult: Equatable, Sendable {
    case ready
    case blocked(SetupIssue)
}
