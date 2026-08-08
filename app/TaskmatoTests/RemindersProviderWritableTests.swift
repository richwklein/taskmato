//
//  RemindersProviderWritableTests.swift
//  TaskmatoTests
//

import EventKit
import Foundation
import Testing

@testable import Taskmato

// MARK: - Writable tests

@Suite("RemindersProvider — writable")
@MainActor
struct RemindersProviderWritableTests {
  private func makeAuthorizedProvider() async throws -> (
    provider: RemindersProvider, store: FakeRemindersEventStore
  ) {
    let store = FakeRemindersEventStore()
    store.status = .fullAccess
    let defaults = UserDefaults(suiteName: UUID().uuidString)!
    let provider = RemindersProvider(store: store, settings: SettingsStore(defaults: defaults))
    try await provider.authorize()
    return (provider, store)
  }

  // MARK: contentFormat

  @Test func contentFormatIsPlainText() async throws {
    let (provider, _) = try await makeAuthorizedProvider()
    #expect(provider.contentFormat == .plainText)
  }

  // MARK: defaultListID

  @Test func defaultListIDFallsBackToStoreDefault() async throws {
    let (provider, store) = try await makeAuthorizedProvider()
    let cal = store.makeCalendar(title: "Work")
    store.stubbedDefaultCalendar = cal
    #expect(provider.defaultListID == cal.calendarIdentifier)
  }

  @Test func defaultListIDReflectsOverrideAfterSetDefaultList() async throws {
    let (provider, store) = try await makeAuthorizedProvider()
    let work = store.makeCalendar(title: "Work")
    let personal = store.makeCalendar(title: "Personal")
    store.stubbedCalendars = [work, personal]
    store.stubbedDefaultCalendar = work
    try await provider.setDefaultList(personal.calendarIdentifier)
    #expect(provider.defaultListID == personal.calendarIdentifier)
  }

  @Test func setDefaultListThrowsForIDOutsideLists() async throws {
    let (provider, _) = try await makeAuthorizedProvider()
    await #expect(throws: RemindersProviderError.self) {
      try await provider.setDefaultList("nonexistent")
    }
  }

  @Test func setDefaultListThrowsForIDFilteredOutByListPatterns() async throws {
    let (provider, store) = try await makeAuthorizedProvider()
    let work = store.makeCalendar(title: "Work")
    let personal = store.makeCalendar(title: "Personal")
    store.stubbedCalendars = [work, personal]
    provider.setListPatterns(["Work"])
    await #expect(throws: RemindersProviderError.self) {
      try await provider.setDefaultList(personal.calendarIdentifier)
    }
  }

  // MARK: addTask

  @Test func addTaskTargetsDraftListIDWhenSet() async throws {
    let (provider, store) = try await makeAuthorizedProvider()
    let work = store.makeCalendar(title: "Work")
    let personal = store.makeCalendar(title: "Personal")
    store.stubbedCalendars = [work, personal]
    store.stubbedDefaultCalendar = work
    var draft = TaskDraft()
    draft.title = "Buy milk"
    draft.listID = personal.calendarIdentifier
    let item = try await provider.addTask(draft)
    #expect(item.list?.id == personal.calendarIdentifier)
    #expect(store.savedReminders.count == 1)
  }

  @Test func addTaskFallsBackToDefaultListID() async throws {
    let (provider, store) = try await makeAuthorizedProvider()
    let work = store.makeCalendar(title: "Work")
    store.stubbedCalendars = [work]
    store.stubbedDefaultCalendar = work
    var draft = TaskDraft()
    draft.title = "Buy milk"
    let item = try await provider.addTask(draft)
    #expect(item.list?.id == work.calendarIdentifier)
  }

  @Test func addTaskThrowsWhenNoListResolves() async throws {
    let (provider, _) = try await makeAuthorizedProvider()
    var draft = TaskDraft()
    draft.title = "Buy milk"
    await #expect(throws: RemindersProviderError.self) {
      try await provider.addTask(draft)
    }
  }

  @Test func addTaskMapsTitleNotesDueDate() async throws {
    let (provider, store) = try await makeAuthorizedProvider()
    let work = store.makeCalendar(title: "Work")
    store.stubbedCalendars = [work]
    store.stubbedDefaultCalendar = work
    var draft = TaskDraft()
    draft.title = "Buy milk"
    draft.notes = "2%"
    draft.dueDate = Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 15))
    let item = try await provider.addTask(draft)
    #expect(item.title == "Buy milk")
    #expect(item.notes == "2%")
    let comps = Calendar.current.dateComponents([.year, .month, .day], from: item.dueDate!)
    #expect(comps.year == 2026)
    #expect(comps.month == 6)
    #expect(comps.day == 15)
  }

  @Test(
    arguments: [
      (TaskPriority.none, 0),
      (TaskPriority.lowest, 9),
      (TaskPriority.low, 9),
      (TaskPriority.medium, 5),
      (TaskPriority.high, 1),
      (TaskPriority.highest, 1),
    ]
  )
  func addTaskMapsPriorityToThreeBands(
    priority: TaskPriority, expectedEKPriority: Int
  ) async throws {
    let (provider, store) = try await makeAuthorizedProvider()
    let work = store.makeCalendar(title: "Work")
    store.stubbedCalendars = [work]
    store.stubbedDefaultCalendar = work
    var draft = TaskDraft()
    draft.title = "Task"
    draft.priority = priority
    _ = try await provider.addTask(draft)
    #expect(store.savedReminders.first?.priority == expectedEKPriority)
  }

  // MARK: updateTask

  @Test func updateTaskMutatesAndResaves() async throws {
    let (provider, store) = try await makeAuthorizedProvider()
    let cal = store.makeCalendar(title: "Work")
    store.stubbedCalendars = [cal]
    let reminder = store.makeReminder(title: "Original", calendar: cal)
    store.stubbedReminders = [reminder]
    let ref = TaskRef(providerID: "reminders", nativeID: reminder.calendarItemIdentifier)
    var draft = TaskDraft()
    draft.title = "Updated"
    try await provider.updateTask(ref, draft: draft)
    #expect(reminder.title == "Updated")
    #expect(store.savedReminders.count == 1)
  }

  @Test func updateTaskReparentsToNewCalendar() async throws {
    let (provider, store) = try await makeAuthorizedProvider()
    let work = store.makeCalendar(title: "Work")
    let personal = store.makeCalendar(title: "Personal")
    store.stubbedCalendars = [work, personal]
    let reminder = store.makeReminder(title: "Task", calendar: work)
    store.stubbedReminders = [reminder]
    let ref = TaskRef(providerID: "reminders", nativeID: reminder.calendarItemIdentifier)
    var draft = TaskDraft()
    draft.title = "Task"
    draft.listID = personal.calendarIdentifier
    try await provider.updateTask(ref, draft: draft)
    #expect(reminder.calendar?.calendarIdentifier == personal.calendarIdentifier)
  }

  @Test func updateTaskThrowsForUnknownRef() async throws {
    let (provider, _) = try await makeAuthorizedProvider()
    let ref = TaskRef(providerID: "reminders", nativeID: "nonexistent")
    var draft = TaskDraft()
    draft.title = "Task"
    await #expect(throws: RemindersProviderError.self) {
      try await provider.updateTask(ref, draft: draft)
    }
  }

  // MARK: deleteTask

  @Test func deleteTaskCallsStoreRemove() async throws {
    let (provider, store) = try await makeAuthorizedProvider()
    let cal = store.makeCalendar(title: "Work")
    let reminder = store.makeReminder(title: "Task", calendar: cal)
    store.stubbedReminders = [reminder]
    let ref = TaskRef(providerID: "reminders", nativeID: reminder.calendarItemIdentifier)
    try await provider.deleteTask(ref)
    #expect(store.removedReminders.count == 1)
  }

  @Test func deleteTaskThrowsForUnknownRef() async throws {
    let (provider, _) = try await makeAuthorizedProvider()
    let ref = TaskRef(providerID: "reminders", nativeID: "nonexistent")
    await #expect(throws: RemindersProviderError.self) {
      try await provider.deleteTask(ref)
    }
  }
}
