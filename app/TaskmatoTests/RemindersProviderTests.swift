//
//  RemindersProviderTests.swift
//  TaskmatoTests
//

import EventKit
import Foundation
import Testing

@testable import Taskmato

// MARK: - Fake store tests

@Suite("RemindersEventStore protocol")

@MainActor
struct RemindersEventStoreTests {

  @Test func fakeStoreReturnsConfiguredStatus() {
    let store = FakeRemindersEventStore()
    store.status = .fullAccess
    #expect(store.authorizationStatus() == .fullAccess)
  }

  @Test func fakeStoreReturnsConfiguredCalendars() {
    let store = FakeRemindersEventStore()
    let cal = store.makeCalendar(title: "Shopping")
    store.stubbedCalendars = [cal]
    #expect(store.calendars(for: .reminder).count == 1)
    #expect(store.calendars(for: .reminder).first?.title == "Shopping")
  }

  @Test func fakeStoreReturnsConfiguredReminders() async throws {
    let store = FakeRemindersEventStore()
    let reminder = store.makeReminder(title: "Buy milk")
    store.stubbedReminders = [reminder]
    let fetched = try await store.fetchIncompleteReminders(in: nil)
    #expect(fetched.count == 1)
    #expect(fetched.first?.title == "Buy milk")
  }

  @Test func fakeStoreRecordsSave() throws {
    let store = FakeRemindersEventStore()
    let reminder = store.makeReminder(title: "Test")
    try store.save(reminder, commit: true)
    #expect(store.savedReminders.count == 1)
    #expect(store.savedReminders.first?.title == "Test")
  }
}

// MARK: - Authorization tests
@Suite("RemindersProvider — authorization")
@MainActor
struct RemindersProviderAuthorizationTests {

  private func makeProvider(
    status: EKAuthorizationStatus = .notDetermined,
    grantAccess: Bool = true
  ) -> (RemindersProvider, FakeRemindersEventStore) {
    let store = FakeRemindersEventStore()
    store.status = status
    store.grantAccess = grantAccess
    let provider = RemindersProvider(store: store)
    return (provider, store)
  }

  @Test func providerIDIsReminders() {
    let (provider, _) = makeProvider()
    #expect(provider.id == "reminders")
  }

  @Test func displayNameIsAppleReminders() {
    let (provider, _) = makeProvider()
    #expect(provider.displayName == "Apple Reminders")
  }

  @Test func entitlementIsFree() {
    let (provider, _) = makeProvider()
    #expect(provider.entitlement == .free)
  }

  @Test func authorizeWhenNotDetermined_requestsAccess() async throws {
    let (provider, store) = makeProvider(status: .notDetermined)
    try await provider.authorize()
    #expect(store.didRequestAccess)
    #expect(provider.isAuthorized)
  }

  @Test func authorizeWhenAlreadyFullAccess_doesNotRequestAgain() async throws {
    let (provider, store) = makeProvider(status: .fullAccess)
    try await provider.authorize()
    #expect(!store.didRequestAccess)
    #expect(provider.isAuthorized)
  }

  @Test func authorizeWhenDenied_throwsAccessDenied() async {
    let (provider, _) = makeProvider(status: .denied)
    await #expect(throws: RemindersProviderError.accessDenied) {
      try await provider.authorize()
    }
    #expect(!provider.isAuthorized)
  }

  @Test func authorizeWhenRestricted_throwsAccessRestricted() async {
    let (provider, _) = makeProvider(status: .restricted)
    await #expect(throws: RemindersProviderError.accessRestricted) {
      try await provider.authorize()
    }
    #expect(!provider.isAuthorized)
  }

  @Test func authorizeWhenWriteOnly_throwsFullAccessRequired() async {
    let (provider, _) = makeProvider(status: .writeOnly)
    await #expect(throws: RemindersProviderError.fullAccessRequired) {
      try await provider.authorize()
    }
    #expect(!provider.isAuthorized)
  }

  @Test func authorizeWhenRequestReturnsFalse_throwsAccessDenied() async {
    let (provider, _) = makeProvider(status: .notDetermined, grantAccess: false)
    await #expect(throws: RemindersProviderError.accessDenied) {
      try await provider.authorize()
    }
    #expect(!provider.isAuthorized)
  }

  @Test func listsReturnsEmptyWhenNotAuthorized() async throws {
    let (provider, _) = makeProvider()
    let lists = try await provider.lists()
    #expect(lists.isEmpty)
  }

  @Test func tasksReturnsEmptyWhenNotAuthorized() async throws {
    let (provider, _) = makeProvider()
    let tasks = try await provider.tasks(in: nil)
    #expect(tasks.isEmpty)
  }
}

// MARK: - Lists tests
@Suite("RemindersProvider — lists")
@MainActor
struct RemindersProviderListTests {

  private func makeAuthorizedProvider() async throws -> (
    provider: RemindersProvider, store: FakeRemindersEventStore
  ) {
    let store = FakeRemindersEventStore()
    store.status = .fullAccess
    let provider = RemindersProvider(store: store)
    try await provider.authorize()
    return (provider, store)
  }

  @Test func listsReturnsEmptyWhenNoCalendars() async throws {
    let (provider, _) = try await makeAuthorizedProvider()
    let lists = try await provider.lists()
    #expect(lists.isEmpty)
  }

  @Test func listsMapsSingleCalendar() async throws {
    let (provider, store) = try await makeAuthorizedProvider()
    store.stubbedCalendars = [store.makeCalendar(title: "Shopping")]
    let lists = try await provider.lists()
    #expect(lists.count == 1)
  }

  @Test func listsUsesCalendarIdentifierAsListID() async throws {
    let (provider, store) = try await makeAuthorizedProvider()
    let cal = store.makeCalendar(title: "Work")
    store.stubbedCalendars = [cal]
    let lists = try await provider.lists()
    #expect(lists.first?.id == cal.calendarIdentifier)
  }

  @Test func listsUsesCalendarTitleAsListName() async throws {
    let (provider, store) = try await makeAuthorizedProvider()
    store.stubbedCalendars = [store.makeCalendar(title: "Groceries")]
    let lists = try await provider.lists()
    #expect(lists.first?.name == "Groceries")
  }

  @Test func listsReturnsMultipleCalendars() async throws {
    let (provider, store) = try await makeAuthorizedProvider()
    store.stubbedCalendars = [
      store.makeCalendar(title: "Work"),
      store.makeCalendar(title: "Personal"),
    ]
    let lists = try await provider.lists()
    #expect(lists.count == 2)
    #expect(lists.map(\.name) == ["Work", "Personal"])
  }
}

// MARK: - Tasks tests
@Suite("RemindersProvider — tasks")
@MainActor
struct RemindersProviderTaskTests {

  private func makeAuthorizedProvider() async throws -> (
    provider: RemindersProvider, store: FakeRemindersEventStore
  ) {
    let store = FakeRemindersEventStore()
    store.status = .fullAccess
    let provider = RemindersProvider(store: store)
    try await provider.authorize()
    return (provider, store)
  }

  @Test func tasksReturnsEmptyWhenNoReminders() async throws {
    let (provider, _) = try await makeAuthorizedProvider()
    let tasks = try await provider.tasks(in: nil)
    #expect(tasks.isEmpty)
  }

  @Test func tasksMapsTitleCorrectly() async throws {
    let (provider, store) = try await makeAuthorizedProvider()
    let cal = store.makeCalendar(title: "Work")
    store.stubbedCalendars = [cal]
    store.stubbedReminders = [store.makeReminder(title: "Ship feature", calendar: cal)]
    let tasks = try await provider.tasks(in: nil)
    #expect(tasks.first?.title == "Ship feature")
  }

  @Test func tasksMapsNotesToNotes() async throws {
    let (provider, store) = try await makeAuthorizedProvider()
    let cal = store.makeCalendar(title: "Work")
    store.stubbedCalendars = [cal]
    store.stubbedReminders = [
      store.makeReminder(title: "Task", notes: "Some notes", calendar: cal)
    ]
    let tasks = try await provider.tasks(in: nil)
    #expect(tasks.first?.notes == "Some notes")
  }

  @Test func tasksNoteFormatIsPlainText() async throws {
    let (provider, store) = try await makeAuthorizedProvider()
    let cal = store.makeCalendar(title: "Work")
    store.stubbedCalendars = [cal]
    store.stubbedReminders = [store.makeReminder(title: "Task", calendar: cal)]
    let tasks = try await provider.tasks(in: nil)
    #expect(tasks.first?.format == .plainText)
  }

  @Test func tasksUsesCalendarItemIdentifierAsNativeID() async throws {
    let (provider, store) = try await makeAuthorizedProvider()
    let cal = store.makeCalendar(title: "Work")
    store.stubbedCalendars = [cal]
    let reminder = store.makeReminder(title: "Task", calendar: cal)
    store.stubbedReminders = [reminder]
    let tasks = try await provider.tasks(in: nil)
    #expect(tasks.first?.id.nativeID == reminder.calendarItemIdentifier)
  }

  @Test func tasksProviderIDIsReminders() async throws {
    let (provider, store) = try await makeAuthorizedProvider()
    let cal = store.makeCalendar(title: "Work")
    store.stubbedCalendars = [cal]
    store.stubbedReminders = [store.makeReminder(title: "Task", calendar: cal)]
    let tasks = try await provider.tasks(in: nil)
    #expect(tasks.first?.id.providerID == "reminders")
  }

  @Test func tasksMapsNoPriorityToNone() async throws {
    let (provider, store) = try await makeAuthorizedProvider()
    let cal = store.makeCalendar(title: "Work")
    store.stubbedCalendars = [cal]
    store.stubbedReminders = [store.makeReminder(title: "Task", priority: 0, calendar: cal)]
    let tasks = try await provider.tasks(in: nil)
    #expect(tasks.first?.priority == TaskPriority.none)
  }

  @Test func tasksMapsEKPriority1ToHigh() async throws {
    let (provider, store) = try await makeAuthorizedProvider()
    let cal = store.makeCalendar(title: "Work")
    store.stubbedCalendars = [cal]
    store.stubbedReminders = [store.makeReminder(title: "Task", priority: 1, calendar: cal)]
    let tasks = try await provider.tasks(in: nil)
    #expect(tasks.first?.priority == .high)
  }

  @Test func tasksMapsEKPriority5ToMedium() async throws {
    let (provider, store) = try await makeAuthorizedProvider()
    let cal = store.makeCalendar(title: "Work")
    store.stubbedCalendars = [cal]
    store.stubbedReminders = [store.makeReminder(title: "Task", priority: 5, calendar: cal)]
    let tasks = try await provider.tasks(in: nil)
    #expect(tasks.first?.priority == .medium)
  }

  @Test func tasksMapsEKPriority9ToLow() async throws {
    let (provider, store) = try await makeAuthorizedProvider()
    let cal = store.makeCalendar(title: "Work")
    store.stubbedCalendars = [cal]
    store.stubbedReminders = [store.makeReminder(title: "Task", priority: 9, calendar: cal)]
    let tasks = try await provider.tasks(in: nil)
    #expect(tasks.first?.priority == .low)
  }

  @Test func tasksMapsDueDateFromDateComponents() async throws {
    let (provider, store) = try await makeAuthorizedProvider()
    let cal = store.makeCalendar(title: "Work")
    store.stubbedCalendars = [cal]
    let reminder = store.makeReminder(title: "Task", calendar: cal)
    reminder.dueDateComponents = DateComponents(year: 2026, month: 6, day: 15)
    store.stubbedReminders = [reminder]
    let tasks = try await provider.tasks(in: nil)
    let dueDate = tasks.first?.dueDate
    #expect(dueDate != nil)
    let comps = Calendar.current.dateComponents([.year, .month, .day], from: dueDate!)
    #expect(comps.year == 2026)
    #expect(comps.month == 6)
    #expect(comps.day == 15)
  }

  @Test func tasksScopesToListWhenProvided() async throws {
    let (provider, store) = try await makeAuthorizedProvider()
    let workCal = store.makeCalendar(title: "Work")
    let personalCal = store.makeCalendar(title: "Personal")
    store.stubbedCalendars = [workCal, personalCal]
    store.stubbedReminders = [
      store.makeReminder(title: "Work task", calendar: workCal),
      store.makeReminder(title: "Personal task", calendar: personalCal),
    ]
    let workList = TaskList(
      id: workCal.calendarIdentifier,
      providerID: "reminders",
      name: "Work"
    )
    let tasks = try await provider.tasks(in: workList)
    #expect(tasks.count == 1)
    #expect(tasks.first?.title == "Work task")
  }

  @Test func tasksReturnsAllWhenListIsNil() async throws {
    let (provider, store) = try await makeAuthorizedProvider()
    let cal = store.makeCalendar(title: "Work")
    store.stubbedCalendars = [cal]
    store.stubbedReminders = [
      store.makeReminder(title: "Task 1", calendar: cal),
      store.makeReminder(title: "Task 2", calendar: cal),
    ]
    let tasks = try await provider.tasks(in: nil)
    #expect(tasks.count == 2)
  }
}

// MARK: - Mutation tests
@Suite("RemindersProvider — mutations")
@MainActor
struct RemindersProviderMutationTests {

  private func makeAuthorizedProvider() async throws -> (
    provider: RemindersProvider, store: FakeRemindersEventStore
  ) {
    let store = FakeRemindersEventStore()
    store.status = .fullAccess
    let provider = RemindersProvider(store: store)
    try await provider.authorize()
    return (provider, store)
  }

  @Test func completeSetsIsCompletedTrue() async throws {
    let (provider, store) = try await makeAuthorizedProvider()
    let cal = store.makeCalendar(title: "Work")
    let reminder = store.makeReminder(title: "Task", calendar: cal)
    store.stubbedReminders = [reminder]
    let ref = TaskRef(
      providerID: "reminders",
      nativeID: reminder.calendarItemIdentifier
    )
    try await provider.complete(ref)
    #expect(reminder.isCompleted)
  }

  @Test func completeSavesToStore() async throws {
    let (provider, store) = try await makeAuthorizedProvider()
    let cal = store.makeCalendar(title: "Work")
    let reminder = store.makeReminder(title: "Task", calendar: cal)
    store.stubbedReminders = [reminder]
    let ref = TaskRef(
      providerID: "reminders",
      nativeID: reminder.calendarItemIdentifier
    )
    try await provider.complete(ref)
    #expect(store.savedReminders.count == 1)
  }

  @Test func completeThrowsForUnknownNativeID() async throws {
    let (provider, _) = try await makeAuthorizedProvider()
    let ref = TaskRef(providerID: "reminders", nativeID: "nonexistent")
    await #expect(throws: RemindersProviderError.self) {
      try await provider.complete(ref)
    }
  }

  @Test func reopenSetsIsCompletedFalse() async throws {
    let (provider, store) = try await makeAuthorizedProvider()
    let cal = store.makeCalendar(title: "Work")
    let reminder = store.makeReminder(
      title: "Task", isCompleted: true, calendar: cal
    )
    store.stubbedReminders = [reminder]
    let ref = TaskRef(
      providerID: "reminders",
      nativeID: reminder.calendarItemIdentifier
    )
    try await provider.reopen(ref)
    #expect(!reminder.isCompleted)
  }

  @Test func reopenClearsCompletionDate() async throws {
    let (provider, store) = try await makeAuthorizedProvider()
    let cal = store.makeCalendar(title: "Work")
    let reminder = store.makeReminder(
      title: "Task", isCompleted: true, calendar: cal
    )
    store.stubbedReminders = [reminder]
    let ref = TaskRef(
      providerID: "reminders",
      nativeID: reminder.calendarItemIdentifier
    )
    try await provider.reopen(ref)
    #expect(reminder.completionDate == nil)
  }

  @Test func reopenSavesToStore() async throws {
    let (provider, store) = try await makeAuthorizedProvider()
    let cal = store.makeCalendar(title: "Work")
    let reminder = store.makeReminder(
      title: "Task", isCompleted: true, calendar: cal
    )
    store.stubbedReminders = [reminder]
    let ref = TaskRef(
      providerID: "reminders",
      nativeID: reminder.calendarItemIdentifier
    )
    try await provider.reopen(ref)
    #expect(store.savedReminders.count == 1)
  }

  @Test func reopenThrowsForUnknownNativeID() async throws {
    let (provider, _) = try await makeAuthorizedProvider()
    let ref = TaskRef(providerID: "reminders", nativeID: "nonexistent")
    await #expect(throws: RemindersProviderError.self) {
      try await provider.reopen(ref)
    }
  }
}

// MARK: - completedTasks

@Suite("RemindersProvider — completedTasks")
@MainActor
struct RemindersProviderCompletedTasksTests {

  private func makeAuthorizedProvider() async throws -> (
    provider: RemindersProvider, store: FakeRemindersEventStore
  ) {
    let store = FakeRemindersEventStore()
    store.grantAccess = true
    let provider = RemindersProvider(store: store)
    try await provider.authorize()
    return (provider, store)
  }

  @Test func completedTasksReturnsEmptyWhenNone() async throws {
    let (provider, _) = try await makeAuthorizedProvider()
    let tasks = try await provider.completedTasks()
    #expect(tasks.isEmpty)
  }

  @Test func completedTasksReturnsCompletedReminders() async throws {
    let (provider, store) = try await makeAuthorizedProvider()
    let cal = store.makeCalendar(title: "Work")
    store.stubbedCalendars = [cal]
    store.stubbedReminders = [
      store.makeReminder(
        title: "Done Task", isCompleted: true, calendar: cal
      ),
      store.makeReminder(
        title: "Open Task", isCompleted: false, calendar: cal
      ),
    ]
    let tasks = try await provider.completedTasks()
    #expect(tasks.count == 1)
    #expect(tasks.first?.title == "Done Task")
  }

  @Test func completedTasksReturnsEmptyWhenNotAuthorized() async throws {
    let store = FakeRemindersEventStore()
    store.stubbedReminders = [
      store.makeReminder(title: "Done", isCompleted: true)
    ]
    let provider = RemindersProvider(store: store)
    let tasks = try await provider.completedTasks()
    #expect(tasks.isEmpty)
  }
}
