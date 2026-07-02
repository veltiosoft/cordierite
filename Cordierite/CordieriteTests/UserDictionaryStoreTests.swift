import XCTest

@testable import Cordierite

@MainActor
final class UserDictionaryStoreTests: XCTestCase {
  private var temporaryDirectory: URL!

  override func setUp() async throws {
    temporaryDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
  }

  override func tearDown() async throws {
    if let temporaryDirectory {
      try? FileManager.default.removeItem(at: temporaryDirectory)
    }
  }

  func testAddPersistsEntries() throws {
    let fileURL = temporaryDirectory.appendingPathComponent("user-dictionary.json")
    let store = UserDictionaryStore(fileURL: fileURL)

    try store.add(source: "foo", replacement: "bar")

    let reloaded = UserDictionaryStore(fileURL: fileURL)
    XCTAssertEqual(reloaded.entries.count, 1)
    XCTAssertEqual(reloaded.entries.first?.source, "foo")
    XCTAssertEqual(reloaded.entries.first?.replacement, "bar")
  }

  func testAddRejectsEmptySource() {
    let fileURL = temporaryDirectory.appendingPathComponent("user-dictionary.json")
    let store = UserDictionaryStore(fileURL: fileURL)

    XCTAssertThrowsError(try store.add(source: "   ", replacement: "bar")) { error in
      XCTAssertEqual(error as? UserDictionaryStoreError, .emptySource)
    }
  }

  func testAddRejectsEntryBeyondLimit() throws {
    let fileURL = temporaryDirectory.appendingPathComponent("user-dictionary.json")
    let store = UserDictionaryStore(fileURL: fileURL)

    for index in 0..<UserDictionaryStore.maxEntryCount {
      try store.add(source: "word\(index)", replacement: "replacement\(index)")
    }

    XCTAssertThrowsError(try store.add(source: "overflow", replacement: "nope")) { error in
      XCTAssertEqual(error as? UserDictionaryStoreError, .entryLimitReached)
    }
    XCTAssertEqual(store.entryCount, UserDictionaryStore.maxEntryCount)
  }
}
