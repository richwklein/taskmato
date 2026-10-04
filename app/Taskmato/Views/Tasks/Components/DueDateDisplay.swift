//
//  DueDateDisplay.swift
//  Taskmato
//

import Foundation

/// A due date rendered for a task row: its label, tooltip, spoken form, and urgency tier.
struct DueDateDisplay {

  /// Which urgency tier a due date falls into, which decides the row's color and glyph.
  enum Urgency {
    /// The due date has passed.
    case overdue
    /// The due date falls today and has not passed.
    case today
    /// The due date is tomorrow or later.
    case upcoming
  }

  /// The row label, e.g. "Today, 5:00 PM" or "Oct 12".
  let text: String
  /// The unabbreviated due date for the tooltip, with no status prefix.
  let tooltipText: String
  /// The spoken label, which also names the tier the color carries visually.
  let accessibleText: String
  /// The tier the color and glyph derive from.
  let urgency: Urgency

  /// - Parameters:
  ///   - dueDate: The due instant; date-only dates sit at the calendar's local midnight.
  ///   - includesTime: Whether `dueDate` carries a meaningful time of day.
  ///   - now: The reference instant.
  ///   - calendar: The calendar for day arithmetic and formatting.
  ///   - locale: The locale for every produced string.
  init(
    dueDate: Date, includesTime: Bool,
    now: Date = .now, calendar: Calendar = .current, locale: Locale = .current
  ) {
    let dayOffset =
      calendar.dateComponents(
        [.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: dueDate)
      ).day ?? 0

    func style() -> Date.FormatStyle {
      Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
    }
    let relative = RelativeDateTimeFormatter()
    relative.dateTimeStyle = .named
    relative.formattingContext = .beginningOfSentence
    relative.locale = locale
    relative.calendar = calendar

    let sameYear = calendar.isDate(dueDate, equalTo: now, toGranularity: .year)
    let absolute = dueDate.formatted(
      sameYear ? style().month(.abbreviated).day() : style().month(.abbreviated).day().year())

    let day: String
    switch dayOffset {
    case ..<0:
      day = absolute
    case 0, 1:
      day = relative.localizedString(from: DateComponents(day: dayOffset))
    case 2...6:
      day = dueDate.formatted(style().weekday(.wide))
    default:
      day = absolute
    }

    let time = includesTime ? dueDate.formatted(style().hour().minute()) : nil
    text = time.map { "\(day), \($0)" } ?? day

    let full = dueDate.formatted(
      includesTime
        ? style().weekday(.wide).month(.wide).day().year().hour().minute()
        : style().weekday(.wide).month(.wide).day().year())
    tooltipText = full

    let isOverdue = includesTime ? dueDate < now : dayOffset < 0
    urgency = isOverdue ? .overdue : (dayOffset == 0 ? .today : .upcoming)

    switch urgency {
    case .overdue: accessibleText = "Overdue, \(full)"
    case .today: accessibleText = "Due today, \(full)"
    case .upcoming: accessibleText = "Due \(full)"
    }
  }
}
