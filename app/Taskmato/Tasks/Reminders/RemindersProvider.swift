//
//  RemindersProvider.swift
//  Taskmato
//

import EventKit
import Foundation

/// A task provider backed by Apple Reminders via EventKit.
///
/// Authorization is lazy: ``lists()`` and ``tasks(in:)`` return empty arrays until
/// ``authorize()`` succeeds. The provider conforms to ``MutableTaskProvider`` so
/// completing a Pomodoro can mark the reminder done in the source system.
@Observable
@MainActor
final class RemindersProvider: MutableTaskProvider {

  /// Stable provider identifier used in ``TaskRef`` values.
  static let providerID = "reminders"

  let id: String = RemindersProvider.providerID
  let displayName: String = "Apple Reminders"
  let entitlement: ProviderEntitlement = .free

  /// Whether the user has granted full Reminders access.
  private(set) var isAuthorized = false

  private let store: any RemindersEventStore
  private var streamContinuation: AsyncStream<[TaskItem]>.Continuation?
  private var observer: NSObjectProtocol?
  private var debounceTask: Task<Void, Never>?

  /// Production initializer using live EventKit.
  convenience init() {
    self.init(store: LiveRemindersEventStore())
  }

  /// Test-friendly initializer accepting any ``RemindersEventStore`` conformer.
  init(store: any RemindersEventStore) {
    self.store = store
    isAuthorized = store.authorizationStatus() == .fullAccess
  }

  // MARK: - Authorization

  /// Requests full Reminders access if not already granted.
  ///
  /// Throws a ``RemindersProviderError`` when the request is denied, restricted,
  /// or when only write-only access is available (insufficient for reading reminders).
  func authorize() async throws {
    let status = store.authorizationStatus()
    switch status {
    case .fullAccess:
      isAuthorized = true
    case .notDetermined:
      let granted = try await store.requestFullAccess()
      guard granted else { throw RemindersProviderError.accessDenied }
      isAuthorized = true
    case .denied:
      throw RemindersProviderError.accessDenied
    case .restricted:
      throw RemindersProviderError.accessRestricted
    case .writeOnly:
      throw RemindersProviderError.fullAccessRequired
    @unknown default:
      throw RemindersProviderError.accessDenied
    }
  }

  // MARK: - TaskProvider

  func lists() async throws -> [TaskList] {
    guard isAuthorized else { return [] }
    return store.calendars(for: .reminder).map { calendar in
      TaskList(
        id: calendar.calendarIdentifier,
        providerID: Self.providerID,
        name: calendar.title
      )
    }
  }

  func tasks(in list: TaskList?) async throws -> [TaskItem] {
    guard isAuthorized else { return [] }
    let calendars: [EKCalendar]?
    if let list {
      let all = store.calendars(for: .reminder)
      calendars = all.filter { $0.calendarIdentifier == list.id }
    } else {
      calendars = nil
    }
    let reminders = try await store.fetchIncompleteReminders(in: calendars)
    return reminders.map { mapToTaskItem($0) }
  }

  func observe() -> AsyncStream<[TaskItem]>? {
    guard isAuthorized else { return nil }
    let (stream, continuation) = AsyncStream<[TaskItem]>.makeStream()
    streamContinuation = continuation
    observer = store.addObserver(
      forName: .EKEventStoreChanged
    ) { [weak self] in
      Task { @MainActor [weak self] in
        self?.scheduleDebounce()
      }
    }
    continuation.onTermination = { [weak self] _ in
      Task { @MainActor [weak self] in
        self?.stopObserving()
      }
    }
    return stream
  }

  private func scheduleDebounce() {
    debounceTask?.cancel()
    debounceTask = Task { [weak self] in
      try? await Task.sleep(for: .milliseconds(250))
      guard !Task.isCancelled, let self else { return }
      let updated = (try? await self.tasks(in: nil)) ?? []
      self.streamContinuation?.yield(updated)
    }
  }

  private func stopObserving() {
    debounceTask?.cancel()
    debounceTask = nil
    if let observer {
      store.removeObserver(observer)
      self.observer = nil
    }
    streamContinuation?.finish()
    streamContinuation = nil
  }

  // MARK: - MutableTaskProvider

  func completedTasks() async throws -> [TaskItem] {
    guard isAuthorized else { return [] }
    let now = Date()
    let sevenDaysAgo = Calendar.current.date(
      byAdding: .day, value: -7, to: now
    )!
    let interval = DateInterval(start: sevenDaysAgo, end: now)
    let reminders = try await store.fetchCompletedReminders(
      in: nil, within: interval
    )
    return reminders.map { mapToTaskItem($0) }
  }

  func complete(_ ref: TaskRef) async throws {
    guard let reminder = store.reminder(withIdentifier: ref.nativeID) else {
      throw RemindersProviderError.reminderNotFound(ref.nativeID)
    }
    reminder.isCompleted = true
    try store.save(reminder, commit: true)
  }

  func reopen(_ ref: TaskRef) async throws {
    guard let reminder = store.reminder(withIdentifier: ref.nativeID) else {
      throw RemindersProviderError.reminderNotFound(ref.nativeID)
    }
    reminder.isCompleted = false
    reminder.completionDate = nil
    try store.save(reminder, commit: true)
  }

  // MARK: - Mapping

  /// Maps an ``EKReminder`` to a provider-agnostic ``TaskItem``.
  private func mapToTaskItem(_ reminder: EKReminder) -> TaskItem {
    TaskItem(
      id: TaskRef(
        providerID: Self.providerID,
        nativeID: reminder.calendarItemIdentifier
      ),
      title: reminder.title ?? "",
      notes: reminder.notes,
      format: .plainText,
      priority: mapPriority(reminder.priority),
      dueDate: reminder.dueDateComponents.flatMap {
        Calendar.current.date(from: $0)
      },
      scheduledDate: nil,
      startDate: reminder.startDateComponents.flatMap {
        Calendar.current.date(from: $0)
      },
      list: TaskList(
        id: reminder.calendar.calendarIdentifier,
        providerID: Self.providerID,
        name: reminder.calendar.title
      ),
      sourceURL: URL(
        string:
          "x-apple-reminderkit://REMCDReminder/\(reminder.calendarItemIdentifier)"
      )
    )
  }

  /// Maps the CalDAV priority integer to ``TaskPriority``, matching Apple Reminders UI.
  private func mapPriority(_ ekPriority: Int) -> TaskPriority {
    switch ekPriority {
    case 0: .none
    case 1...4: .high
    case 5: .medium
    case 6...9: .low
    default: .none
    }
  }
}

// MARK: - Errors

/// Errors thrown by ``RemindersProvider`` operations.
enum RemindersProviderError: LocalizedError, Equatable {

  /// The user denied Reminders access or dismissed the permission dialog.
  case accessDenied

  /// The device restricts Reminders access (e.g. MDM or parental controls).
  case accessRestricted

  /// Only write-only access was granted; full access is required to read reminders.
  case fullAccessRequired

  /// No reminder with the given identifier exists in the store.
  case reminderNotFound(String)

  var errorDescription: String? {
    switch self {
    case .accessDenied:
      return
        "Reminders access was denied. "
        + "Grant access in System Settings > Privacy & Security > Reminders."
    case .accessRestricted:
      return "Reminders access is restricted on this device."
    case .fullAccessRequired:
      return
        "Full Reminders access is required. "
        + "Grant full access in System Settings > Privacy & Security > Reminders."
    case .reminderNotFound(let id):
      return "Could not find reminder \"\(id)\"."
    }
  }
}
