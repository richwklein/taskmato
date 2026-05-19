//
//  ObsidianGlobResolverTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

@Suite("ObsidianGlobResolver")
struct ObsidianGlobResolverTests {

  private let resolver = ObsidianGlobResolver()

  /// 2026-04-27 — ISO week 18, month 04, day 27.
  private let referenceDate: Date = {
    var comps = DateComponents()
    comps.year = 2026
    comps.month = 4
    comps.day = 27
    return Calendar(identifier: .iso8601).date(from: comps)!
  }()

  @Test("returns pattern unchanged when no variables present")
  func noVariables() {
    #expect(resolver.resolve("**/*.md", date: referenceDate) == "**/*.md")
  }

  @Test("replaces {week} with zero-padded ISO week number")
  func weekVariable() {
    let week = Calendar(identifier: .iso8601).component(.weekOfYear, from: referenceDate)
    let expected = String(format: "W%02d.md", week)
    #expect(resolver.resolve("W{week}.md", date: referenceDate) == expected)
  }

  @Test("replaces {year} with ISO week-based year")
  func yearVariable() {
    let year = Calendar(identifier: .iso8601).component(.yearForWeekOfYear, from: referenceDate)
    let expected = String(format: "%04d", year)
    #expect(resolver.resolve("{year}", date: referenceDate) == expected)
  }

  @Test("replaces {month} with zero-padded calendar month")
  func monthVariable() {
    let month = Calendar(identifier: .iso8601).component(.month, from: referenceDate)
    let expected = String(format: "%02d", month)
    #expect(resolver.resolve("{month}", date: referenceDate) == expected)
  }

  @Test("replaces {day} with zero-padded calendar day")
  func dayVariable() {
    let day = Calendar(identifier: .iso8601).component(.day, from: referenceDate)
    let expected = String(format: "%02d", day)
    #expect(resolver.resolve("{day}", date: referenceDate) == expected)
  }

  @Test("replaces multiple variables in a single pattern")
  func multipleVariables() {
    let result = resolver.resolve("{year}-W{week}-{month}-{day}.md", date: referenceDate)
    #expect(result == "2026-W18-04-27.md")
  }
}
