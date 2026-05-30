//
//  LiveRemindersEventStore.swift
//  Taskmato
//

import EventKit
import Foundation

/// Thin wrapper delegating to a real ``EKEventStore`` for production use.
final class LiveRemindersEventStore: RemindersEventStore {

  private let store = EKEventStore()

  nonisolated func authorizationStatus() -> EKAuthorizationStatus {
    EKEventStore.authorizationStatus(for: .reminder)
  }

  func requestFullAccess() async throws -> Bool {
    try await store.requestFullAccessToReminders()
  }

  func calendars(for entityType: EKEntityType) -> [EKCalendar] {
    store.calendars(for: entityType)
  }

  func fetchIncompleteReminders(in calendars: [EKCalendar]?) async throws -> [EKReminder] {
    let predicate = store.predicateForIncompleteReminders(
      withDueDateStarting: nil,
      ending: nil,
      calendars: calendars
    )
    return try await withCheckedThrowingContinuation { continuation in
      store.fetchReminders(matching: predicate) { reminders in
        continuation.resume(returning: reminders ?? [])
      }
    }
  }

  func fetchCompletedReminders(
    in calendars: [EKCalendar]?,
    within interval: DateInterval
  ) async throws -> [EKReminder] {
    let predicate = store.predicateForCompletedReminders(
      withCompletionDateStarting: interval.start,
      ending: interval.end,
      calendars: calendars
    )
    return try await withCheckedThrowingContinuation { continuation in
      store.fetchReminders(matching: predicate) { reminders in
        continuation.resume(returning: reminders ?? [])
      }
    }
  }

  func save(_ reminder: EKReminder, commit: Bool) throws {
    try store.save(reminder, commit: commit)
  }

  func reminder(withIdentifier identifier: String) -> EKReminder? {
    store.calendarItem(withIdentifier: identifier) as? EKReminder
  }

  func addObserver(
    forName name: NSNotification.Name,
    using block: @escaping @Sendable () -> Void
  ) -> NSObjectProtocol {
    NotificationCenter.default.addObserver(forName: name, object: store, queue: nil) { _ in
      block()
    }
  }

  func removeObserver(_ observer: NSObjectProtocol) {
    NotificationCenter.default.removeObserver(observer)
  }
}
