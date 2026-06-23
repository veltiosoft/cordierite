import Foundation

enum TextPostProcessor {
    private static let japaneseFillerPattern = #"(?<=[\s、。！？，]|^)(?:えー+|ええと|えっと|あの|その|まあ|なんか|うー+|んー+)[、]?(?=[\s、。！？，]|$)"#
    private static let englishFillerPattern = #"\b(?:uh|um|er|ah|hmm|hm)\b[,]?\s*"#

    static func process(_ text: String, removeFillerWords: Bool) -> String {
        var result = normalizeWhitespace(text)
        result = normalizePunctuationSpacing(result)

        if removeFillerWords {
            result = removeFillers(from: result)
            result = normalizeWhitespace(result)
            result = normalizePunctuationSpacing(result)
        }

        return result
    }

    private static func normalizeWhitespace(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    private static func removeFillers(from text: String) -> String {
        var result = text.replacingOccurrences(
            of: englishFillerPattern,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )

        while true {
            let updated = result.replacingOccurrences(
                of: japaneseFillerPattern,
                with: "",
                options: .regularExpression
            )
            if updated == result {
                break
            }
            result = updated
        }

        return result
    }

    private static func normalizePunctuationSpacing(_ text: String) -> String {
        text
            .replacingOccurrences(of: #" +([、。！？，])"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: #"([、。！？，]) +"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: #"([\.!?,:;]) +"#, with: "$1 ", options: .regularExpression)
            .replacingOccurrences(of: #" +([\.!?,:;])"#, with: "$1", options: .regularExpression)
    }
}
