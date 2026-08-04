//
//  TaskSelectionStoreTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

private func makeItem(providerID: ProviderID, nativeID: String, title: String) -> TaskItem {
  TaskItem(
    id: TaskRef(providerID: providerID, nativeID: nativeID),
    title: title,
    notes: nil,
    format: .plainText,
    priority: .none,
    dueDate: nil,
    scheduledDate: nil,
    startDate: nil,
    list: nil,
    section: nil,
    sourceURL: nil
  )
}

@Suite("TaskSelectionStore")
@MainActor
struct TaskSelectionStoreTests {

  private func makeStore() -> TaskSelectionStore {
    TaskSelectionStore(store: SettingsStore(defaults: UserDefaults(suiteName: UUID().uuidString)!))
  }

  // MARK: - Active task

  @Test func selectSetsActiveTask() {
    let store = makeStore()
    let task = makeItem(providerID: "alpha", nativeID: "1", title: "Write tests")
    store.select(task)
    #expect(store.activeTask == task)
  }

  @Test func clearActiveTaskNilsActiveTask() {
    let store = makeStore()
    store.select(makeItem(providerID: "alpha", nativeID: "1", title: "Write tests"))
    store.clearActiveTask()
    #expect(store.activeTask == nil)
  }

  @Test func activeTaskIsNilByDefault() {
    let store = makeStore()
    #expect(store.activeTask == nil)
  }

  @Test func selectMidSessionSwapsActiveTask() {
    let store = makeStore()
    let first = makeItem(providerID: "alpha", nativeID: "1", title: "First")
    let second = makeItem(providerID: "alpha", nativeID: "2", title: "Second")
    store.select(first)
    store.select(second)
    #expect(store.activeTask == second)
  }

  // MARK: - Recents

  @Test func selectAddsToRecents() {
    let store = makeStore()
    let task = makeItem(providerID: "alpha", nativeID: "1", title: "Write tests")
    store.select(task)
    #expect(store.recents(for: "alpha") == [task])
  }

  @Test func recentsAreNewestFirst() {
    let store = makeStore()
    let first = makeItem(providerID: "alpha", nativeID: "1", title: "First")
    let second = makeItem(providerID: "alpha", nativeID: "2", title: "Second")
    store.select(first)
    store.select(second)
    #expect(store.recents(for: "alpha").map(\.title) == ["Second", "First"])
  }

  @Test func recentsDeduplicated() {
    let store = makeStore()
    let task = makeItem(providerID: "alpha", nativeID: "1", title: "Write tests")
    let other = makeItem(providerID: "alpha", nativeID: "2", title: "Other")
    store.select(task)
    store.select(other)
    store.select(task)
    #expect(store.recents(for: "alpha").map(\.title) == ["Write tests", "Other"])
  }

  @Test func recentsCapAt10() {
    let store = makeStore()
    for index in 1...11 {
      store.select(makeItem(providerID: "alpha", nativeID: "\(index)", title: "Task \(index)"))
    }
    #expect(store.recents(for: "alpha").count == TaskSelectionStore.recentsLimit)
    #expect(store.recents(for: "alpha").first?.title == "Task 11")
  }

  @Test func recentsArePerProvider() {
    let store = makeStore()
    let alphaTask = makeItem(providerID: "alpha", nativeID: "1", title: "Alpha task")
    let betaTask = makeItem(providerID: "beta", nativeID: "1", title: "Beta task")
    store.select(alphaTask)
    store.select(betaTask)
    #expect(store.recents(for: "alpha") == [alphaTask])
    #expect(store.recents(for: "beta") == [betaTask])
  }

  @Test func recentsEmptyForUnknownProvider() {
    let store = makeStore()
    #expect(store.recents(for: "unknown").isEmpty)
  }

  @Test func clearActiveTaskPreservesRecents() {
    let store = makeStore()
    let task = makeItem(providerID: "alpha", nativeID: "1", title: "Write tests")
    store.select(task)
    store.clearActiveTask()
    #expect(store.recents(for: "alpha") == [task])
  }

  // MARK: - Persistence

  @Test func activeTaskSurvivesReload() {
    let suiteName = UUID().uuidString
    let defaults = UserDefaults(suiteName: suiteName)!
    let task = makeItem(providerID: "alpha", nativeID: "1", title: "Persisted task")

    let store = TaskSelectionStore(store: SettingsStore(defaults: defaults))
    store.select(task)

    let reloaded = TaskSelectionStore(store: SettingsStore(defaults: defaults))
    #expect(reloaded.activeTask == task)
  }

  @Test func recentsSurviveReload() {
    let suiteName = UUID().uuidString
    let defaults = UserDefaults(suiteName: suiteName)!
    let task = makeItem(providerID: "alpha", nativeID: "1", title: "Persisted task")

    let store = TaskSelectionStore(store: SettingsStore(defaults: defaults))
    store.select(task)

    let reloaded = TaskSelectionStore(store: SettingsStore(defaults: defaults))
    #expect(reloaded.recents(for: "alpha") == [task])
  }

  @Test func clearedActiveTaskNotRestoredAfterReload() {
    let suiteName = UUID().uuidString
    let defaults = UserDefaults(suiteName: suiteName)!
    let task = makeItem(providerID: "alpha", nativeID: "1", title: "Temp task")

    let store = TaskSelectionStore(store: SettingsStore(defaults: defaults))
    store.select(task)
    store.clearActiveTask()

    let reloaded = TaskSelectionStore(store: SettingsStore(defaults: defaults))
    #expect(reloaded.activeTask == nil)
  }

  // MARK: - onActiveTaskChanged (D4 of design doc 0010)

  @Test func selectFiresOnActiveTaskChangedWithTheNewTask() {
    let store = makeStore()
    let task = makeItem(providerID: "alpha", nativeID: "1", title: "Write tests")
    var observed: TaskItem?
    store.onActiveTaskChanged = { observed = $0 }
    store.select(task)
    #expect(observed == task)
  }

  @Test func clearActiveTaskFiresOnActiveTaskChangedWithNil() {
    let store = makeStore()
    store.select(makeItem(providerID: "alpha", nativeID: "1", title: "Write tests"))
    var fired = false
    var observed: TaskItem?
    store.onActiveTaskChanged = {
      fired = true
      observed = $0
    }
    store.clearActiveTask()
    #expect(fired)
    #expect(observed == nil)
  }

  // MARK: - Pending continuation (D9 of design doc 0010)

  @Test func markPendingContinuationSetsFlag() {
    let store = makeStore()
    store.markPendingContinuation()
    #expect(store.isPendingContinuation)
  }

  @Test func selectAfterPendingContinuationFiresOnContinuationSelect() {
    let store = makeStore()
    var fired = false
    store.onContinuationSelect = { fired = true }
    store.markPendingContinuation()
    store.select(makeItem(providerID: "alpha", nativeID: "1", title: "Next task"))
    #expect(fired)
  }

  @Test func selectAfterPendingContinuationClearsTheFlag() {
    let store = makeStore()
    store.markPendingContinuation()
    store.select(makeItem(providerID: "alpha", nativeID: "1", title: "Next task"))
    #expect(store.isPendingContinuation == false)
  }

  @Test func idleSelectNeverFiresOnContinuationSelect() {
    // No handoff (complete/swap/clear) preceded this pick — an ordinary idle selection.
    let store = makeStore()
    var fired = false
    store.onContinuationSelect = { fired = true }
    store.select(makeItem(providerID: "alpha", nativeID: "1", title: "Any task"))
    #expect(fired == false)
  }

  @Test func onlyTheNextSelectConsumesThePendingContinuation() {
    let store = makeStore()
    var fireCount = 0
    store.onContinuationSelect = { fireCount += 1 }
    store.markPendingContinuation()
    store.select(makeItem(providerID: "alpha", nativeID: "1", title: "First"))
    store.select(makeItem(providerID: "alpha", nativeID: "2", title: "Second"))
    #expect(fireCount == 1)
  }

  @Test func clearPendingContinuationPreventsTheNextSelectFromFiring() {
    let store = makeStore()
    var fired = false
    store.onContinuationSelect = { fired = true }
    store.markPendingContinuation()
    store.clearPendingContinuation()
    store.select(makeItem(providerID: "alpha", nativeID: "1", title: "Task"))
    #expect(fired == false)
  }
}
