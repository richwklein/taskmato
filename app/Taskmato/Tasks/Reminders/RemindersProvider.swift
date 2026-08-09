//
//  RemindersProvider.swift
//  Taskmato
//

import EventKit
import Foundation

/// A task provider backed by Apple Reminders via EventKit.
///
/// Authorization is lazy: ``lists()`` and ``tasks(in:)`` return empty arrays until
/// ``authorize()`` succeeds. The provider conforms to ``WritableTaskProvider`` so tasks can be
/// created, edited, completed, and deleted from Taskmato — but not ``WritableListProvider``:
/// Reminders lists (EventKit calendars) already have a mature native management UI
/// (Reminders.app, iCloud/Exchange account settings), so list create/rename/delete stays out of
/// scope. See ADR-0011.
@Observable
@MainActor
final class RemindersProvider: WritableTaskProvider {

  /// Stable provider identifier used in ``TaskRef`` values.
  static let providerID: ProviderID = "reminders"

  let id: ProviderID = RemindersProvider.providerID
  let displayName: String = "Apple Reminders"
  let icon: String = "checklist"
  let tint: ProviderTint = .orange
  let entitlement: ProviderEntitlement = .free

  /// Whether the user has granted full Reminders access.
  private(set) var isAuthorized = false

  /// Glob patterns used to restrict which calendars ``lists()`` returns.
  /// Empty array means no filtering — all calendars are returned.
  private(set) var listPatterns: [String]

  /// The `ContentFormat` new and edited reminders use — Reminders notes are plain text.
  let contentFormat: ContentFormat = .plainText

  /// User-selected default calendar identifier, or `nil` to fall back to the system default.
  private var defaultListOverride: String? {
    didSet { settings[SettingsStore.Keys.remindersDefaultListOverride] = defaultListOverride }
  }

  /// The ID of the calendar new tasks target by default.
  ///
  /// Reflects an explicit ``setDefaultList(_:)`` override when set, otherwise falls back to
  /// EventKit's own default calendar for new reminders.
  var defaultListID: String? {
    defaultListOverride ?? store.defaultCalendarForNewReminders()?.calendarIdentifier
  }

  private let store: any RemindersEventStore
  private let settings: SettingsStore
  private let updates = MulticastAsyncStream<[TaskItem]>()
  private var observer: NSObjectProtocol?
  private let debouncer = Debouncer()

  /// Production initializer using live EventKit.
  convenience init() {
    self.init(store: LiveRemindersEventStore(), settings: SettingsStore())
  }

  /// Test-friendly initializer accepting any ``RemindersEventStore`` conformer.
  init(store: any RemindersEventStore, settings: SettingsStore = SettingsStore()) {
    self.store = store
    self.settings = settings
    self.listPatterns = settings[SettingsStore.Keys.remindersListPatterns]
    self.defaultListOverride = settings[SettingsStore.Keys.remindersDefaultListOverride]
    isAuthorized = store.authorizationStatus() == .fullAccess
    updates.onEmpty = { [weak self] in self?.stopObserving() }
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

  // MARK: - List pattern filtering

  /// Replaces the stored list-pattern array and persists it to UserDefaults.
  func setListPatterns(_ patterns: [String]) {
    listPatterns = patterns
    settings[SettingsStore.Keys.remindersListPatterns] = listPatterns
  }

  /// Returns titles of all Reminders calendars without applying ``listPatterns``.
  /// Used by the settings UI to compute the N-of-M match preview.
  func allCalendarTitles() -> [String] {
    guard isAuthorized else { return [] }
    return store.calendars(for: .reminder).map(\.title)
  }

  /// Returns `true` if `title` matches any element of `patterns` using `fnmatch`
  /// with `FNM_CASEFOLD`. Internal so the settings view can reuse it for live preview.
  func matchesAnyPattern(title: String, patterns: [String]) -> Bool {
    patterns.contains { fnmatch($0, title, FNM_CASEFOLD) == 0 }
  }

  // MARK: - TaskProvider

  func lists() async throws -> [TaskList] {
    guard isAuthorized else { return [] }
    let all = store.calendars(for: .reminder).map { calendar in
      TaskList(
        id: calendar.calendarIdentifier,
        providerID: Self.providerID,
        name: calendar.title
      )
    }
    guard !listPatterns.isEmpty else { return all }
    return all.filter { matchesAnyPattern(title: $0.name, patterns: listPatterns) }
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
    let stream = updates.subscribe()
    if observer == nil {
      observer = store.addObserver(
        forName: .EKEventStoreChanged
      ) { [weak self] in
        Task { @MainActor [weak self] in
          self?.scheduleDebounce()
        }
      }
    }
    return stream
  }

  private func scheduleDebounce() {
    debouncer.schedule { [weak self] in
      guard let self else { return }
      let updated = (try? await self.tasks(in: nil)) ?? []
      self.updates.yield(updated)
    }
  }

  private func stopObserving() {
    debouncer.cancel()
    if let observer {
      store.removeObserver(observer)
      self.observer = nil
    }
    updates.finish()
  }

  // MARK: - ClosableTaskProvider

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

  // MARK: - WritableTaskProvider

  /// Persists `listID` as the default target for new tasks.
  ///
  /// Validated against the pattern-filtered ``lists()`` set so the default stays consistent
  /// with what the sidebar actually shows.
  func setDefaultList(_ listID: String) async throws {
    guard try await lists().contains(where: { $0.id == listID }) else {
      throw RemindersProviderError.listNotFound(listID)
    }
    defaultListOverride = listID
  }

  /// Creates a new reminder from `draft` and returns the resulting item.
  ///
  /// Targets `draft.listID` if set, otherwise ``defaultListID``.
  @discardableResult
  func addTask(_ draft: TaskDraft) async throws -> TaskItem {
    let calendarID = draft.listID ?? defaultListID
    guard let calendarID,
      let calendar = store.calendars(for: .reminder)
        .first(where: { $0.calendarIdentifier == calendarID })
    else {
      throw RemindersProviderError.listNotFound(calendarID ?? "")
    }
    let reminder = store.newReminder()
    apply(draft, to: reminder, calendar: calendar)
    try store.save(reminder, commit: true)
    return mapToTaskItem(ReminderSnapshot(reminder))
  }

  /// Applies `draft` to the reminder identified by `ref`, including re-parenting to a
  /// different calendar when `draft.listID` differs and resolves to a known calendar.
  func updateTask(_ ref: TaskRef, draft: TaskDraft) async throws {
    guard let reminder = store.reminder(withIdentifier: ref.nativeID) else {
      throw RemindersProviderError.reminderNotFound(ref.nativeID)
    }
    let calendarID = draft.listID ?? reminder.calendar?.calendarIdentifier
    guard let calendarID,
      let calendar = store.calendars(for: .reminder)
        .first(where: { $0.calendarIdentifier == calendarID })
    else {
      throw RemindersProviderError.listNotFound(calendarID ?? "")
    }
    apply(draft, to: reminder, calendar: calendar)
    try store.save(reminder, commit: true)
  }

  /// Permanently removes the reminder identified by `ref` from the store.
  func deleteTask(_ ref: TaskRef) async throws {
    guard let reminder = store.reminder(withIdentifier: ref.nativeID) else {
      throw RemindersProviderError.reminderNotFound(ref.nativeID)
    }
    try store.remove(reminder, commit: true)
  }

  /// Applies `draft`'s fields to `reminder`, assigning it to `calendar`.
  private func apply(_ draft: TaskDraft, to reminder: EKReminder, calendar: EKCalendar) {
    reminder.title = draft.title
    reminder.notes = draft.notes.isEmpty ? nil : draft.notes
    reminder.calendar = calendar
    reminder.priority = mapPriority(draft.priority)
    reminder.dueDateComponents = draft.dueDate.map {
      Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: $0)
    }
  }

  // MARK: - Mapping

  /// Maps a ``ReminderSnapshot`` to a provider-agnostic ``TaskItem``.
  private func mapToTaskItem(_ reminder: ReminderSnapshot) -> TaskItem {
    TaskItem(
      id: TaskRef(
        providerID: Self.providerID,
        nativeID: reminder.calendarItemIdentifier
      ),
      title: reminder.title,
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
        id: reminder.calendarIdentifier,
        providerID: Self.providerID,
        name: reminder.calendarTitle
      ),
      sourceURL: URL(
        string:
          "x-apple-reminderkit://REMCDReminder/\(reminder.calendarItemIdentifier)"
      ),
      createdAt: reminder.creationDate
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

  /// Maps ``TaskPriority`` to the CalDAV priority integer, collapsing to the same 3 bands the
  /// read side maps back from — `lowest`/`low` and `high`/`highest` are indistinguishable on
  /// read, so a write-then-reread round-trips stably.
  private func mapPriority(_ priority: TaskPriority) -> Int {
    switch priority {
    case .none: 0
    case .lowest, .low: 9
    case .medium: 5
    case .high, .highest: 1
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

  /// No calendar with the given identifier is among the provider's current lists.
  case listNotFound(String)

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
    case .listNotFound(let id):
      return "Could not find Reminders list \"\(id)\"."
    }
  }
}
