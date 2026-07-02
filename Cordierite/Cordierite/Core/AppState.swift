import Foundation

struct RecordingFeedback: Equatable, Identifiable, Sendable {
  enum Action: Equatable, Sendable {
    case openPermissionDoctor
    case reloadMicrophones
  }

  let title: String
  let message: String?
  let action: Action?

  var id: String {
    title + (message ?? "")
  }

  static func blocked(by issue: SetupIssue) -> RecordingFeedback {
    RecordingFeedback(
      title: issue.message,
      message: issue.guidance,
      action: .openPermissionDoctor
    )
  }

  static let whisperModelNotReady = RecordingFeedback(
    title: "Whisper model is not ready",
    message: "Download or load the selected model before recording.",
    action: nil
  )

  static let silenceDiscarded = RecordingFeedback(
    title: "No speech detected",
    message: "The recording was too short or too quiet.",
    action: nil
  )

  static let textRemovedByCleanup = RecordingFeedback(
    title: "Nothing left to paste",
    message:
      "Speech was recognized, but cleanup removed all text. Turn off Remove Filler Words or say more.",
    action: nil
  )

  static let recognitionFailed = RecordingFeedback(
    title: "Could not transcribe this recording",
    message: "Try recording again.",
    action: nil
  )

  static let microphoneResetToSystemDefault = RecordingFeedback(
    title: "Selected microphone is unavailable",
    message: "Switched to System Default. Choose a microphone again if needed.",
    action: nil
  )

  static func startFailed(_ error: Error) -> RecordingFeedback {
    if let captureError = error as? AudioCaptureError {
      switch captureError {
      case .deviceNotFound:
        return RecordingFeedback(
          title: "No microphone input device found",
          message: "Reload devices or choose System Default.",
          action: .reloadMicrophones
        )
      case .noInputReceived:
        return RecordingFeedback(
          title: "Microphone input did not become active",
          message: "Check the selected microphone and try again.",
          action: .reloadMicrophones
        )
      case .engineStartFailed:
        return RecordingFeedback(
          title: "Could not start audio capture",
          message: "Try another microphone or restart recording.",
          action: nil
        )
      }
    }

    return RecordingFeedback(
      title: "Could not start recording",
      message: error.localizedDescription,
      action: nil
    )
  }
}

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
