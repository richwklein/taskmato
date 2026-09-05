//
//  WeeklyChartViewportTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

struct WeeklyChartViewportTests {
  private var calendar: Calendar { makeCalendar() }

  @Test func shortHistoryUsesItsActualWidth() {
    let viewport = makeViewport(
      first: date(2026, 1, 5), last: date(2026, 1, 19), now: date(2026, 1, 19))
    #expect(viewport.visibleWidth == 3)
    #expect(viewport.maximumScrollStart == 0)
    #expect(viewport.visibleWeeks(at: 0.5, calendar: calendar).count == 3)
  }

  @Test func pageJumpsClampAtBothDomainEdges() {
    let viewport = makeViewport(
      first: date(2025, 1, 6), last: date(2025, 10, 6), now: date(2025, 10, 6))
    let end = viewport.movedScrollStart(0, by: 500)
    #expect(end == viewport.maximumScrollStart)
    #expect(viewport.movedScrollStart(end, by: -500) == 0)
  }

  @Test func fractionalStartIncludesTwentySevenPartiallyVisibleWeeks() {
    let viewport = makeViewport(
      first: date(2025, 1, 6), last: date(2025, 9, 1), now: date(2025, 9, 1))
    #expect(viewport.visibleWidth == 26)
    #expect(viewport.visibleWeeks(at: 0.5, calendar: calendar).count == 27)
  }

  @Test func expandingHistoryPreservesTheOldLeadingDate() {
    let old = makeViewport(first: date(2025, 4, 7), last: date(2025, 12, 1), now: date(2025, 12, 1))
    let leading = old.leadingWeek(at: 10.5, calendar: calendar)
    let expanded = makeViewport(
      first: date(2024, 1, 1), last: date(2025, 12, 1), now: date(2025, 12, 1))
    #expect(
      expanded.leadingWeek(
        at: expanded.scrollStart(preservingLeadingWeek: leading, calendar: calendar),
        calendar: calendar) == leading)
  }

  @Test func futureHistoryInitiallyEndsAtTheCurrentWeek() {
    let now = date(2026, 3, 2)
    let viewport = makeViewport(first: date(2025, 1, 6), last: date(2027, 1, 4), now: now)
    #expect(
      viewport.leadingWeek(
        at: viewport.initialScrollStart(now: now, calendar: calendar), calendar: calendar)
        == date(2025, 9, 8))
  }

  @Test func statePreservesFractionWhenHistoryExpandsOrChartReappears() {
    let now = date(2025, 12, 1)
    let old = makeViewport(first: date(2025, 4, 7), last: now, now: now)
    var state = WeeklyChartViewportState()
    state.reconcile(old, now: now, calendar: calendar)
    state.scrollStart = 4.5
    #expect(state.scrollStart < old.maximumScrollStart)
    let oldLeading = old.leadingWeek(at: state.scrollStart, calendar: calendar)
    let expanded = makeViewport(first: date(2024, 1, 1), last: now, now: now)
    state.reconcile(expanded, now: now, calendar: calendar)
    #expect(state.scrollStart.truncatingRemainder(dividingBy: 1) == 0.5)
    #expect(expanded.leadingWeek(at: state.scrollStart, calendar: calendar) == oldLeading)
    let retained = state.scrollStart
    state.reconcile(expanded, now: now, calendar: calendar)
    #expect(state.scrollStart == retained)
  }

  @Test func expansionFromTheTrailingEdgeStaysPinnedToTheNewTrailingEdge() {
    let now = date(2025, 12, 1)
    let old = makeViewport(first: date(2025, 4, 7), last: now, now: now)
    var state = WeeklyChartViewportState()
    state.reconcile(old, now: now, calendar: calendar)
    state.scrollStart = old.maximumScrollStart
    let expanded = makeViewport(first: date(2024, 1, 1), last: now, now: now)
    state.reconcile(expanded, now: now, calendar: calendar)
    #expect(state.scrollStart == expanded.maximumScrollStart)
    #expect(
      expanded.leadingWeek(at: state.scrollStart, calendar: calendar)
        == old.leadingWeek(at: old.maximumScrollStart, calendar: calendar))
  }

  @Test func calendarRebucketsAcrossDSTYearAndFirstWeekday() {
    var sundayCalendar = makeCalendar()
    sundayCalendar.firstWeekday = 1
    sundayCalendar.timeZone = TimeZone(identifier: "America/Chicago")!
    let march = date(2026, 3, 8, calendar: sundayCalendar)
    let viewport = WeeklyChartViewport(
      earliestPositiveWeek: march, lastRecordedWeek: date(2027, 1, 3, calendar: sundayCalendar),
      now: march, calendar: sundayCalendar)!
    #expect(WeeklyChartViewport.weekStart(march, calendar: sundayCalendar) == march)
    #expect(
      viewport.offset(for: date(2027, 1, 3, calendar: sundayCalendar), calendar: sundayCalendar)
        > 40)
  }

  @Test func monthTicksKeepDateIdentityAndFractionalPosition() {
    let viewport = makeViewport(
      first: date(2026, 1, 26), last: date(2026, 3, 9), now: date(2026, 3, 9))
    let february = date(2026, 2, 1)
    #expect(viewport.monthBoundaryDates(calendar: calendar).contains(february))
    #expect(viewport.monthPosition(for: february, calendar: calendar) > 0)
    #expect(viewport.monthPosition(for: february, calendar: calendar) < 1)
  }

  @Test func calendarChangeRemapsLeadingDateToItsNewContainingWeek() {
    let oldCalendar = calendar
    var newCalendar = calendar
    newCalendar.firstWeekday = 1
    let now = date(2026, 5, 4)
    let old = WeeklyChartViewport(
      earliestPositiveWeek: date(2026, 1, 5), lastRecordedWeek: now, now: now,
      calendar: oldCalendar)!
    var state = WeeklyChartViewportState()
    state.reconcile(old, now: now, calendar: oldCalendar)
    state.scrollStart = 1.5
    let leadingDate = old.leadingWeek(at: state.scrollStart, calendar: oldCalendar)
    let rebucketed = WeeklyChartViewport(
      earliestPositiveWeek: date(2026, 1, 5), lastRecordedWeek: now, now: now,
      calendar: newCalendar)!
    state.reconcile(rebucketed, now: now, calendar: newCalendar)
    #expect(
      rebucketed.leadingWeek(at: state.scrollStart, calendar: newCalendar)
        == WeeklyChartViewport.weekStart(leadingDate, calendar: newCalendar))
  }

  @Test func stateCreatesDomainWhenTotalsChangeFromZeroToPositive() {
    let week = date(2026, 6, 1)
    let viewport = WeeklyChartViewport(
      earliestPositiveWeek: week, lastRecordedWeek: week, now: week, calendar: calendar)!
    var state = WeeklyChartViewportState()
    state.reconcile(nil, now: week, calendar: calendar)
    state.reconcile(viewport, now: week, calendar: calendar)
    #expect(state.scrollStart == 0)
  }

  private func makeViewport(first: Date, last: Date, now: Date) -> WeeklyChartViewport {
    WeeklyChartViewport(
      earliestPositiveWeek: first, lastRecordedWeek: last, now: now, calendar: calendar)!
  }
  private func makeCalendar() -> Calendar {
    var value = Calendar(identifier: .gregorian)
    value.timeZone = TimeZone(secondsFromGMT: 0)!
    value.firstWeekday = 2
    return value
  }
  private func date(_ year: Int, _ month: Int, _ day: Int, calendar: Calendar? = nil) -> Date {
    (calendar ?? self.calendar).date(from: DateComponents(year: year, month: month, day: day))!
  }
}
