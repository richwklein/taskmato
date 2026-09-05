//
//  WeeklyChartViewport.swift
//  Taskmato
//

import Foundation

/// Maps calendar weeks onto the fixed numeric coordinate system used by the weekly chart.
struct WeeklyChartViewport: Equatable {
  /// The largest number of weeks presented in one screenful.
  static let pageLength = 26
  /// The calendar week represented by coordinate zero.
  let firstWeek: Date
  /// The first calendar week outside the chart domain.
  let endWeekExclusive: Date
  /// The number of whole calendar weeks in the chart domain.
  let weekCount: Int
  /// The number of weeks visible at once, shortened for a small history.
  let visibleWidth: Int

  /// Creates the domain from its earliest positive total through the later of now and history.
  init?(earliestPositiveWeek: Date, lastRecordedWeek: Date, now: Date, calendar: Calendar) {
    let firstWeek = Self.weekStart(earliestPositiveWeek, calendar: calendar)
    let currentWeek = Self.weekStart(now, calendar: calendar)
    let lastWeek = max(Self.weekStart(lastRecordedWeek, calendar: calendar), currentWeek)
    guard let endWeekExclusive = calendar.date(byAdding: .weekOfYear, value: 1, to: lastWeek) else {
      return nil
    }
    self.firstWeek = firstWeek
    self.endWeekExclusive = endWeekExclusive
    self.weekCount = max(
      1,
      calendar.dateComponents([.weekOfYear], from: firstWeek, to: endWeekExclusive).weekOfYear ?? 1)
    self.visibleWidth = min(Self.pageLength, weekCount)
  }

  /// Returns the initial leading coordinate, ending the window at the current week when possible.
  func initialScrollStart(now: Date, calendar: Calendar) -> Double {
    clampedScrollStart(Double(offset(for: now, calendar: calendar) - visibleWidth + 1))
  }

  /// Returns the coordinate for the start of a calendar week in this domain.
  func offset(for date: Date, calendar: Calendar) -> Int {
    calendar.dateComponents(
      [.weekOfYear], from: firstWeek, to: Self.weekStart(date, calendar: calendar)
    ).weekOfYear ?? 0
  }

  /// Returns the calendar week at a possibly fractional chart coordinate.
  func leadingWeek(at scrollStart: Double, calendar: Calendar) -> Date {
    calendar.date(
      byAdding: .weekOfYear, value: Int(floor(clampedScrollStart(scrollStart))), to: firstWeek)
      ?? firstWeek
  }

  /// Clamps a chart coordinate to the available domain while retaining its fractional part.
  func clampedScrollStart(_ scrollStart: Double) -> Double {
    min(max(0, scrollStart), maximumScrollStart)
  }

  /// Returns the coordinate that preserves an absolute leading date after a domain or calendar update.
  func scrollStart(preservingLeadingWeek date: Date, calendar: Calendar) -> Double {
    clampedScrollStart(Double(offset(for: date, calendar: calendar)))
  }

  /// Returns every whole week touched by the current fractional visible range.
  func visibleWeeks(at scrollStart: Double, calendar: Calendar) -> [Date] {
    let start = Int(floor(clampedScrollStart(scrollStart)))
    let end = min(weekCount, Int(ceil(clampedScrollStart(scrollStart) + Double(visibleWidth))))
    guard start < end else { return [] }
    return (start..<end).compactMap {
      calendar.date(byAdding: .weekOfYear, value: $0, to: firstWeek)
    }
  }

  /// Returns month-boundary dates that fall inside this chart domain.
  func monthBoundaryDates(calendar: Calendar) -> [Date] {
    guard
      var month = calendar.date(from: calendar.dateComponents([.year, .month], from: firstWeek))
    else { return [] }
    var dates: [Date] = []
    while month < endWeekExclusive {
      if month >= firstWeek { dates.append(month) }
      guard let next = calendar.date(byAdding: .month, value: 1, to: month) else { break }
      month = next
    }
    return dates
  }

  /// Returns the actual fractional coordinate for a month boundary date.
  func monthPosition(for monthBoundary: Date, calendar: Calendar) -> Double {
    let week = Self.weekStart(monthBoundary, calendar: calendar)
    let fraction =
      calendar.dateInterval(of: .weekOfYear, for: monthBoundary).map {
        monthBoundary.timeIntervalSince($0.start) / $0.duration
      } ?? 0
    return Double(offset(for: week, calendar: calendar)) + fraction
  }

  /// Whether a preceding 26-week jump is available.
  func canMoveBackward(from scrollStart: Double) -> Bool { clampedScrollStart(scrollStart) > 0 }
  /// Whether a following 26-week jump is available.
  func canMoveForward(from scrollStart: Double) -> Bool {
    clampedScrollStart(scrollStart) < maximumScrollStart
  }
  /// Returns a coordinate moved by a page and clamped to the domain.
  func movedScrollStart(_ scrollStart: Double, by weeks: Int) -> Double {
    clampedScrollStart(scrollStart + Double(weeks))
  }
  /// The greatest valid leading coordinate.
  var maximumScrollStart: Double { Double(max(0, weekCount - visibleWidth)) }
  /// Normalizes a date to the containing calendar week's start.
  static func weekStart(_ date: Date, calendar: Calendar) -> Date {
    calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
  }
}

/// Persists one fractional chart coordinate and the context needed to reconcile a changing domain.
struct WeeklyChartViewportState: Equatable {
  /// The chart's sole scroll position, measured in weeks from the active domain origin.
  var scrollStart = 0.0

  private var previousViewport: WeeklyChartViewport?
  private var previousCalendar: Calendar?

  /// Reconciles history or calendar changes while preserving the old absolute leading week.
  mutating func reconcile(_ viewport: WeeklyChartViewport?, now: Date, calendar: Calendar) {
    guard let viewport else {
      previousViewport = nil
      previousCalendar = nil
      return
    }
    if let previousViewport, let previousCalendar {
      let current = previousViewport.clampedScrollStart(scrollStart)
      let leading = previousViewport.leadingWeek(at: current, calendar: previousCalendar)
      let remapped = viewport.scrollStart(preservingLeadingWeek: leading, calendar: calendar)
      if previousCalendar == calendar {
        scrollStart = viewport.clampedScrollStart(remapped + current - floor(current))
      } else {
        scrollStart = remapped
      }
    } else {
      scrollStart = viewport.initialScrollStart(now: now, calendar: calendar)
    }
    previousViewport = viewport
    previousCalendar = calendar
  }
}
