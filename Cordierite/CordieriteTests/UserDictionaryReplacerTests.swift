import XCTest

@testable import Cordierite

final class UserDictionaryReplacerTests: XCTestCase {
  func testApplyReplacesMatchingSource() {
    let entries = [
      UserDictionaryEntry(source: "コーディエライト", replacement: "Cordierite")
    ]

    let result = UserDictionaryReplacer.apply("これはコーディエライトです", entries: entries)

    XCTAssertEqual(result, "これはCordieriteです")
  }

  func testApplyUsesLongestMatch() {
    let entries = [
      UserDictionaryEntry(source: "東京", replacement: "Tokyo"),
      UserDictionaryEntry(source: "東京都", replacement: "Tokyo Metropolis"),
    ]

    let result = UserDictionaryReplacer.apply("東京都に行く", entries: entries)

    XCTAssertEqual(result, "Tokyo Metropolisに行く")
  }

  func testApplyIsCaseSensitive() {
    let entries = [
      UserDictionaryEntry(source: "iPhone", replacement: "iPhone")
    ]

    let result = UserDictionaryReplacer.apply("iphone is great", entries: entries)

    XCTAssertEqual(result, "iphone is great")
  }

  func testApplySkipsDisabledEntries() {
    let entries = [
      UserDictionaryEntry(source: "foo", replacement: "bar", isEnabled: false)
    ]

    let result = UserDictionaryReplacer.apply("foo baz", entries: entries)

    XCTAssertEqual(result, "foo baz")
  }

  func testApplyReturnsOriginalTextWhenNoMatch() {
    let entries = [
      UserDictionaryEntry(source: "alpha", replacement: "beta")
    ]

    let result = UserDictionaryReplacer.apply("gamma", entries: entries)

    XCTAssertEqual(result, "gamma")
  }

  func testApplyWithEmptyEntriesReturnsOriginalText() {
    let result = UserDictionaryReplacer.apply("unchanged", entries: [])

    XCTAssertEqual(result, "unchanged")
  }

  func testApplyReplacesMultipleOccurrences() {
    let entries = [
      UserDictionaryEntry(source: "cat", replacement: "dog")
    ]

    let result = UserDictionaryReplacer.apply("cat and cat", entries: entries)

    XCTAssertEqual(result, "dog and dog")
  }
}
