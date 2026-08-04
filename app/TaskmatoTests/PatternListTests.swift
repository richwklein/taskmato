//
//  PatternListTests.swift
//  TaskmatoTests
//

import Testing

@testable import Taskmato

@Suite("PatternList")
struct PatternListTests {

  @Test func parseEmptyStringReturnsEmptyList() {
    #expect(PatternList.parse("") == [])
  }

  @Test func parseWhitespaceOnlyEntriesAreDropped() {
    #expect(PatternList.parse("  ,   ,\t") == [])
  }

  @Test func parseTrimsSurroundingWhitespace() {
    #expect(PatternList.parse("  **/*.md  ") == ["**/*.md"])
  }

  @Test func parseMultiplePatternsSeparatedByCommas() {
    #expect(
      PatternList.parse("Work*, *Personal*,  daily/{YYYY}-{MM}-{DD}.md")
        == ["Work*", "*Personal*", "daily/{YYYY}-{MM}-{DD}.md"])
  }
}
