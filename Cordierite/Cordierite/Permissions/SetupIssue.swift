import Foundation

enum SetupIssue: Identifiable, Equatable, Sendable {
    case microphoneRequired
    case microphoneDenied
    case inputMonitoringRequired
    case accessibilityRequired

    var id: String {
        switch self {
        case .microphoneRequired:
            "microphoneRequired"
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
        case .microphoneRequired:
            "Microphone permission is required"
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
        case .microphoneRequired:
            "Click Start Recording or Request Access in Permission Doctor to allow microphone access."
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
        case .microphoneRequired, .microphoneDenied:
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
    case ready(microphoneJustGranted: Bool = false)
    case blocked(SetupIssue)
}
