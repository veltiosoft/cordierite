import Foundation

@MainActor
final class TranscriptBuffer {
    private var finalized = ""
    private var volatile = ""

    var finalizedText: String {
        finalized
    }

    var displayText: String {
        finalized + volatile
    }

    func reset() {
        finalized = ""
        volatile = ""
    }

    func apply(event: RecognitionEvent) {
        switch event {
        case .partial(let text):
            volatile = text
        case .final(let text):
            finalized += text
            volatile = ""
        }
    }

    func applyResult(isFinal: Bool, text: String) {
        if isFinal {
            finalized += text
            volatile = ""
        } else {
            volatile = text
        }
    }
}
