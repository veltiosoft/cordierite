import Foundation

enum AppState: String, Sendable {
    case loading
    case ready
    case starting
    case recording
    case processing
    case needsSetup

    var menuBarTitle: String {
        switch self {
        case .loading:
            "Loading"
        case .ready:
            "Ready"
        case .starting:
            "Starting"
        case .recording:
            "Recording"
        case .processing:
            "Processing"
        case .needsSetup:
            "Needs Setup"
        }
    }

    var systemImageName: String {
        switch self {
        case .loading:
            "hourglass"
        case .ready:
            "mic"
        case .starting:
            "mic"
        case .recording:
            "mic.fill"
        case .processing:
            "ellipsis.circle"
        case .needsSetup:
            "exclamationmark.triangle"
        }
    }
}
