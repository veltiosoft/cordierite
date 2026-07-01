import Foundation

struct UserDictionaryEntry: Codable, Identifiable, Equatable, Sendable {
  let id: UUID
  var source: String
  var replacement: String
  var isEnabled: Bool

  init(
    id: UUID = UUID(),
    source: String,
    replacement: String,
    isEnabled: Bool = true
  ) {
    self.id = id
    self.source = source
    self.replacement = replacement
    self.isEnabled = isEnabled
  }
}
