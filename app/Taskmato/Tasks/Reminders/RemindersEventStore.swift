//
//  RemindersEventStore.swift
//  Taskmato
//

import EventKit
import Foundation

/// Abstraction over ``EKEventStore`` for testability.
///
/// ``LiveRemindersEventStore`` wraps the real system store;
/// tests inject a fake that returns pre-configured data without
/// requiring Reminders access or TCC authorization.
@MainActor
protocol RemindersEventStore: AnyObject, Sendable {

  /// Returns the app's current authorization status for reminders.
  nonisolated func authorizationStatus() -> EKAuthorizationStatus

  /// Requests full read/write access to the user's reminders.
  func requestFullAccess() async throws -> Bool

  /// Returns all reminder calendars (lists) visible to the app.
  func calendars(for entityType: EKEntityType) -> [EKCalendar]

  /// Fetches incomplete reminders, optionally scoped to specific calendars.
  func fetchIncompleteReminders(in calendars: [EKCalendar]?) async throws -> [EKReminder]

  /// Fetches completed reminders within a date range, optionally scoped to specific calendars.
  func fetchCompletedReminders(
    in calendars: [EKCalendar]?,
    within interval: DateInterval
  ) async throws -> [EKReminder]

  /// Saves a modified reminder to the store.
  func save(_ reminder: EKReminder, commit: Bool) throws

  /// Looks up a reminder by its stable ``EKReminder/calendarItemIdentifier``.
  func reminder(withIdentifier identifier: String) -> EKReminder?

  /// Registers an observer for a notification (e.g. ``EKEventStoreChanged``).
  func addObserver(
    forName name: NSNotification.Name,
    using block: @escaping @Sendable () -> Void
  ) -> NSObjectProtocol

  /// Removes a previously registered observer.
  func removeObserver(_ observer: NSObjectProtocol)
}
