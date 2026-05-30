//
//  RemindersProviderObserveTests.swift
//  TaskmatoTests
//

import EventKit
import Foundation
import Testing

@testable import Taskmato

// MARK: - Observe tests
@Suite("RemindersProvider — observe")
@MainActor
struct RemindersProviderObserveTests {

  private func makeAuthorizedProvider() async throws -> (
    provider: RemindersProvider, store: FakeRemindersEventStore
  ) {
    let store = FakeRemindersEventStore()
    store.grantAccess = true
    let provider = RemindersProvider(store: store)
    try await provider.authorize()
    return (provider, store)
  }

  @Test func observeReturnsNilWhenNotAuthorized() {
    let store = FakeRemindersEventStore()
    let provider = RemindersProvider(store: store)
    #expect(provider.observe() == nil)
  }

  @Test func observeReturnsStreamWhenAuthorized() async throws {
    let (provider, _) = try await makeAuthorizedProvider()
    #expect(provider.observe() != nil)
  }

  @Test func observeEmitsUpdatedTasksOnNotification() async throws {
    let (provider, store) = try await makeAuthorizedProvider()
    let cal = store.makeCalendar(title: "Work")
    store.stubbedCalendars = [cal]
    store.stubbedReminders = [
      store.makeReminder(title: "Task 1", calendar: cal)
    ]

    guard let stream = provider.observe() else {
      Issue.record("observe() returned nil")
      return
    }

    var iterator = stream.makeAsyncIterator()
    store.fireNotification()

    let emitted = await iterator.next()
    #expect(emitted?.count == 1)
    #expect(emitted?.first?.title == "Task 1")
  }

  @Test func observeDebounceCoalescesBurstNotifications() async throws {
    let (provider, store) = try await makeAuthorizedProvider()
    let cal = store.makeCalendar(title: "Work")
    store.stubbedCalendars = [cal]
    store.stubbedReminders = [
      store.makeReminder(title: "Task 1", calendar: cal)
    ]

    guard let stream = provider.observe() else {
      Issue.record("observe() returned nil")
      return
    }

    var iterator = stream.makeAsyncIterator()

    for _ in 0..<5 {
      store.fireNotification()
    }

    let first = await iterator.next()
    #expect(first?.count == 1)

    store.stubbedReminders = [
      store.makeReminder(title: "Task 1", calendar: cal),
      store.makeReminder(title: "Task 2", calendar: cal),
    ]
    store.fireNotification()

    let second = await iterator.next()
    #expect(second?.count == 2)
  }
}
