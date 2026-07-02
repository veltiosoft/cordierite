import Foundation

enum UserDictionaryReplacer {
  static func apply(_ text: String, entries: [UserDictionaryEntry]) -> String {
    let activeEntries =
      entries
      .filter(\.isEnabled)
      .filter { !$0.source.isEmpty }

    guard !activeEntries.isEmpty else {
      return text
    }

    var result = ""
    var index = text.startIndex

    while index < text.endIndex {
      if let match = longestMatch(in: text, startingAt: index, entries: activeEntries) {
        result.append(match.replacement)
        index = text.index(index, offsetBy: match.sourceLength)
      } else {
        result.append(text[index])
        index = text.index(after: index)
      }
    }

    return result
  }

  private struct Match {
    let replacement: String
    let sourceLength: Int
  }

  private static func longestMatch(
    in text: String,
    startingAt startIndex: String.Index,
    entries: [UserDictionaryEntry]
  ) -> Match? {
    var bestMatch: Match?

    for entry in entries {
      let source = entry.source
      guard text[startIndex...].hasPrefix(source) else {
        continue
      }

      let candidate = Match(replacement: entry.replacement, sourceLength: source.count)
      if let current = bestMatch {
        if candidate.sourceLength > current.sourceLength {
          bestMatch = candidate
        }
      } else {
        bestMatch = candidate
      }
    }

    return bestMatch
  }
}
