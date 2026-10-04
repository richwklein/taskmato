//
//  DueDateDisplayTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

@Suite("DueDateDisplay")
struct DueDateDisplayTests {

  private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
    return calendar
  }()
  private let locale = Locale(identifier: "en_US")

  /// Saturday, October 3 2026, 2:00 PM in the fixture calendar.
  private var now: Date { at(2026, 10, 3, 14) }

  private func at(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
  }

  private func display(_ due: Date, time: Bool) -> DueDateDisplay {
    DueDateDisplay(
      dueDate: due, includesTime: time, now: now, calendar: calendar, locale: locale)
  }

  // MARK: - Tiers

  @Test func dateOnlyTodayIsTodayNotOverdue() {
    let result = display(calendar.startOfDay(for: now), time: false)
    #expect(result.text.normalizingSpaces == "Today")
    #expect(result.urgency == .today)
  }

  @Test func timedTodayLaterIsToday() {
    let result = display(at(2026, 10, 3, 17), time: true)
    #expect(result.text.normalizingSpaces == "Today, 5:00 PM")
    #expect(result.urgency == .today)
  }

  @Test func timedTodayAlreadyPassedIsOverdue() {
    let result = display(at(2026, 10, 3, 9), time: true)
    #expect(result.text.normalizingSpaces == "Today, 9:00 AM")
    #expect(result.urgency == .overdue)
  }

  @Test func tomorrowReadsAsWord() {
    #expect(display(at(2026, 10, 4), time: false).text.normalizingSpaces == "Tomorrow")
    #expect(display(at(2026, 10, 4, 9), time: true).text.normalizingSpaces == "Tomorrow, 9:00 AM")
    #expect(display(at(2026, 10, 4), time: false).urgency == .upcoming)
  }

  @Test func twoToSixDaysAheadReadsAsWeekday() {
    #expect(display(at(2026, 10, 6), time: false).text.normalizingSpaces == "Tuesday")
    #expect(display(at(2026, 10, 9, 9), time: true).text.normalizingSpaces == "Friday, 9:00 AM")
  }

  @Test func sevenDaysAheadReadsAsDate() {
    #expect(display(at(2026, 10, 10), time: false).text.normalizingSpaces == "Oct 10")
    #expect(display(at(2026, 10, 12, 9), time: true).text.normalizingSpaces == "Oct 12, 9:00 AM")
  }

  @Test func nextCalendarYearIncludesYear() {
    #expect(display(at(2027, 11, 2), time: false).text.normalizingSpaces == "Nov 2, 2027")
    #expect(
      display(at(2027, 11, 2, 9), time: true).text.normalizingSpaces == "Nov 2, 2027, 9:00 AM")
  }

  // MARK: - Past days

  @Test func yesterdayReadsAsDateNeverAsWord() {
    let dateOnly = display(at(2026, 10, 2), time: false)
    let timed = display(at(2026, 10, 2, 17), time: true)
    #expect(dateOnly.text.normalizingSpaces == "Oct 2")
    #expect(timed.text.normalizingSpaces == "Oct 2, 5:00 PM")
    #expect(dateOnly.urgency == .overdue)
    #expect(timed.urgency == .overdue)
    #expect(!dateOnly.text.contains("Yesterday"))
    #expect(!timed.text.contains("Yesterday"))
  }

  @Test func olderPastDayReadsAsDate() {
    let result = display(at(2026, 10, 1), time: false)
    #expect(result.text.normalizingSpaces == "Oct 1")
    #expect(result.urgency == .overdue)
  }

  // MARK: - Accessibility and tooltip

  @Test func accessibleTextNamesTheTier() {
    #expect(display(at(2026, 10, 2), time: false).accessibleText.hasPrefix("Overdue, "))
    #expect(display(at(2026, 10, 3), time: false).accessibleText.hasPrefix("Due today, "))
    #expect(display(at(2026, 10, 6), time: false).accessibleText.hasPrefix("Due Tuesday"))
  }

  @Test func tooltipHasNoStatusPrefix() {
    let result = display(at(2026, 10, 2, 9), time: true)
    #expect(result.tooltipText.normalizingSpaces == "Friday, October 2, 2026 at 9:00 AM")
    #expect(!result.tooltipText.contains("Overdue"))
  }
}

extension String {
  /// Replaces the narrow no-break space ICU puts before AM/PM with a plain space.
  fileprivate var normalizingSpaces: String {
    replacingOccurrences(of: "\u{202F}", with: " ")
  }
}
