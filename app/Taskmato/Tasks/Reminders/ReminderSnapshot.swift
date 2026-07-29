//
//  ReminderSnapshot.swift
//  Taskmato
//

import EventKit
import Foundation

/// A `Sendable` value snapshot of the ``EKReminder`` fields Taskmato reads.
///
/// EventKit's `EKReminder` is a non-`Sendable` reference type whose fetch callbacks fire on an
/// arbitrary queue. Capturing the needed fields into this value at the fetch boundary lets results
/// cross back to the main actor without sending a non-`Sendable` object across isolation domains.
nonisolated struct ReminderSnapshot: Sendable {

  /// Stable ``EKReminder/calendarItemIdentifier`` used to build the ``TaskRef``.
  let calendarItemIdentifier: String

  /// The reminder title, or an empty string when unset.
  let title: String

  /// Optional reminder notes.
  let notes: String?

  /// The CalDAV priority integer (0–9).
  let priority: Int

  /// Due-date components, if the reminder has a due date.
  let dueDateComponents: DateComponents?

  /// Start-date components, if the reminder has a start date.
  let startDateComponents: DateComponents?

  /// Identifier of the calendar (list) the reminder belongs to.
  let calendarIdentifier: String

  /// Title of the calendar (list) the reminder belongs to.
  let calendarTitle: String

  /// When the reminder was created, if known.
  let creationDate: Date?
}

extension ReminderSnapshot {

  /// Captures the fields Taskmato reads from a live ``EKReminder``.
  ///
  /// `nonisolated` so it can run inside EventKit's off-main fetch completion.
  nonisolated init(_ reminder: EKReminder) {
    self.init(
      calendarItemIdentifier: reminder.calendarItemIdentifier,
      title: reminder.title ?? "",
      notes: reminder.notes,
      priority: reminder.priority,
      dueDateComponents: reminder.dueDateComponents,
      startDateComponents: reminder.startDateComponents,
      calendarIdentifier: reminder.calendar?.calendarIdentifier ?? "",
      calendarTitle: reminder.calendar?.title ?? "",
      creationDate: reminder.creationDate)
  }
}
