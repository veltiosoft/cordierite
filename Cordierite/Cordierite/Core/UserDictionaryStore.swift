import Foundation

enum UserDictionaryStoreError: LocalizedError, Equatable, Sendable {
  case entryLimitReached
  case emptySource

  var errorDescription: String? {
    switch self {
    case .entryLimitReached:
      "The user dictionary is limited to \(UserDictionaryStore.maxEntryCount) entries."
    case .emptySource:
      "Source text cannot be empty."
    }
  }
}

@MainActor
@Observable
final class UserDictionaryStore {
  nonisolated static let maxEntryCount = 20

  private(set) var entries: [UserDictionaryEntry] = []

  private let fileURL: URL

  var enabledEntries: [UserDictionaryEntry] {
    entries.filter(\.isEnabled)
  }

  var entryCount: Int {
    entries.count
  }

  var remainingEntryCount: Int {
    max(0, Self.maxEntryCount - entries.count)
  }

  var canAddEntry: Bool {
    entries.count < Self.maxEntryCount
  }

  static var dictionaryFileURL: URL {
    ConfigStore.configDirectoryURL.appendingPathComponent("user-dictionary.json")
  }

  init(fileURL: URL = UserDictionaryStore.dictionaryFileURL) {
    self.fileURL = fileURL
    entries = Self.load(from: fileURL) ?? []
  }

  func add(source: String, replacement: String) throws {
    let trimmedSource = source.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedSource.isEmpty else {
      throw UserDictionaryStoreError.emptySource
    }
    guard canAddEntry else {
      throw UserDictionaryStoreError.entryLimitReached
    }

    let entry = UserDictionaryEntry(
      source: trimmedSource,
      replacement: replacement.trimmingCharacters(in: .whitespacesAndNewlines)
    )
    entries.append(entry)
    save()
  }

  func update(_ entry: UserDictionaryEntry) throws {
    let trimmedSource = entry.source.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedSource.isEmpty else {
      throw UserDictionaryStoreError.emptySource
    }
    guard let index = entries.firstIndex(where: { $0.id == entry.id }) else {
      return
    }

    entries[index] = UserDictionaryEntry(
      id: entry.id,
      source: trimmedSource,
      replacement: entry.replacement.trimmingCharacters(in: .whitespacesAndNewlines),
      isEnabled: entry.isEnabled
    )
    save()
  }

  func delete(id: UUID) {
    entries.removeAll { $0.id == id }
    save()
  }

  func toggleEnabled(id: UUID) {
    guard let index = entries.firstIndex(where: { $0.id == id }) else {
      return
    }
    entries[index].isEnabled.toggle()
    save()
  }

  func save() {
    do {
      try FileManager.default.createDirectory(
        at: fileURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      let data = try encoder.encode(entries)
      try data.write(to: fileURL, options: .atomic)
    } catch {
      NSLog("Failed to save user dictionary: \(error.localizedDescription)")
    }
  }

  private static func load(from fileURL: URL) -> [UserDictionaryEntry]? {
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      return nil
    }

    do {
      let data = try Data(contentsOf: fileURL)
      return try JSONDecoder().decode([UserDictionaryEntry].self, from: data)
    } catch {
      NSLog("Failed to load user dictionary: \(error.localizedDescription)")
      return nil
    }
  }
}
