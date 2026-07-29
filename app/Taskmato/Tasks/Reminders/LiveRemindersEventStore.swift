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

  func fetchIncompleteReminders(in calendars: [EKCalendar]?) async throws -> [ReminderSnapshot] {
    let predicate = store.predicateForIncompleteReminders(
      withDueDateStarting: nil,
      ending: nil,
      calendars: calendars
    )
    return try await withCheckedThrowingContinuation { continuation in
      // The completion fires on an arbitrary EventKit queue, so it must be @Sendable (nonisolated) —
      // otherwise the module's default main-actor isolation traps when it runs off the main thread.
      // Snapshot here so only Sendable values escape the continuation.
      store.fetchReminders(matching: predicate) { @Sendable reminders in
        continuation.resume(returning: (reminders ?? []).map(ReminderSnapshot.init))
      }
    }
  }

  func fetchCompletedReminders(
    in calendars: [EKCalendar]?,
    within interval: DateInterval
  ) async throws -> [ReminderSnapshot] {
    let predicate = store.predicateForCompletedReminders(
      withCompletionDateStarting: interval.start,
      ending: interval.end,
      calendars: calendars
    )
    return try await withCheckedThrowingContinuation { continuation in
      // See fetchIncompleteReminders — the completion runs off the main thread and must be @Sendable.
      store.fetchReminders(matching: predicate) { @Sendable reminders in
        continuation.resume(returning: (reminders ?? []).map(ReminderSnapshot.init))
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
