//
//  FakeRemindersEventStore.swift
//  TaskmatoTests
//

import EventKit
import Foundation

@testable import Taskmato

/// In-memory fake of ``RemindersEventStore`` for unit tests.
///
/// Pre-configure `status`, `stubbedCalendars`, and `stubbedReminders` before
/// exercising the provider under test. `savedReminders` records every `save` call.
@MainActor
final class FakeRemindersEventStore: RemindersEventStore {

  /// The authorization status returned by ``authorizationStatus()``.
  var status: EKAuthorizationStatus = .notDetermined

  /// Whether ``requestFullAccess()`` should return `true` or `false`.
  var grantAccess = true

  /// Whether ``requestFullAccess()`` was called.
  private(set) var didRequestAccess = false

  /// Calendars returned by ``calendars(for:)``.
  var stubbedCalendars: [EKCalendar] = []

  /// Reminders returned by fetch methods (filtered by `isCompleted`).
  var stubbedReminders: [EKReminder] = []

  /// Reminders passed to ``save(_:commit:)``, in call order.
  private(set) var savedReminders: [EKReminder] = []

  /// Callback registered via ``addObserver(forName:using:)``.
  /// Call ``fireNotification()`` to invoke it from tests.
  private var observerCallback: (@Sendable () -> Void)?
  private var observerToken: NSObjectProtocol?

  /// The underlying ``EKEventStore`` used to create in-memory ``EKReminder`` objects.
  let backingStore = EKEventStore()

  // MARK: - RemindersEventStore

  nonisolated func authorizationStatus() -> EKAuthorizationStatus {
    // Safe to access — tests set this before any concurrent use.
    MainActor.assumeIsolated { status }
  }

  func requestFullAccess() async throws -> Bool {
    didRequestAccess = true
    if grantAccess {
      status = .fullAccess
    }
    return grantAccess
  }

  func calendars(for entityType: EKEntityType) -> [EKCalendar] {
    stubbedCalendars
  }

  func fetchIncompleteReminders(in calendars: [EKCalendar]?) async throws -> [EKReminder] {
    let incomplete = stubbedReminders.filter { !$0.isCompleted }
    guard let calendars else { return incomplete }
    let ids = Set(calendars.map(\.calendarIdentifier))
    return incomplete.filter { ids.contains($0.calendar.calendarIdentifier) }
  }

  func fetchCompletedReminders(
    in calendars: [EKCalendar]?,
    within interval: DateInterval
  ) async throws -> [EKReminder] {
    stubbedReminders.filter { $0.isCompleted }
  }

  func save(_ reminder: EKReminder, commit: Bool) throws {
    savedReminders.append(reminder)
  }

  func reminder(withIdentifier identifier: String) -> EKReminder? {
    stubbedReminders.first { $0.calendarItemIdentifier == identifier }
  }

  func addObserver(
    forName name: NSNotification.Name,
    using block: @escaping @Sendable () -> Void
  ) -> NSObjectProtocol {
    observerCallback = block
    let token = NSObject()
    observerToken = token
    return token
  }

  func removeObserver(_ observer: NSObjectProtocol) {
    observerCallback = nil
    observerToken = nil
  }

  // MARK: - Test helpers

  /// Simulates an ``EKEventStoreChangedNotification`` by invoking the registered observer callback.
  func fireNotification() {
    observerCallback?()
  }

  /// Creates an ``EKReminder`` backed by this fake's ``backingStore`` for use in test fixtures.
  func makeReminder(
    title: String = "Test Reminder",
    notes: String? = nil,
    priority: Int = 0,
    isCompleted: Bool = false,
    calendar: EKCalendar? = nil
  ) -> EKReminder {
    let reminder = EKReminder(eventStore: backingStore)
    reminder.title = title
    reminder.notes = notes
    reminder.priority = priority
    reminder.isCompleted = isCompleted
    if let calendar {
      reminder.calendar = calendar
    }
    return reminder
  }

  /// Creates an ``EKCalendar`` backed by this fake's ``backingStore`` for use in test fixtures.
  func makeCalendar(title: String = "Test List") -> EKCalendar {
    let calendar = EKCalendar(for: .reminder, eventStore: backingStore)
    calendar.title = title
    return calendar
  }
}
