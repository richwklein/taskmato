//
//  TimerSearchPresenterTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

// MARK: - Fakes

/// Returns a fixed task set from `tasks(in:)`, optionally suspending the call until
/// ``resumeFetch()`` — used to land a query change in the window between a fetch starting and
/// its result being observed.
@MainActor
private final class SearchStubProvider: TaskProvider {
  let id: ProviderID
  let displayName: String
  let icon: String = "square"
  let entitlement: ProviderEntitlement = .free
  var stubbedTasks: [TaskItem]
  var suspendFetch = false
  private(set) var isFetchSuspended = false
  private var fetchContinuation: CheckedContinuation<Void, Never>?

  init(id: ProviderID, tasks: [TaskItem] = []) {
    self.id = id
    self.displayName = id.rawValue
    self.stubbedTasks = tasks
  }

  func authorize() async throws {}
  func lists() async throws -> [TaskList] { [] }
  func tasks(in _: TaskList?) async throws -> [TaskItem] {
    if suspendFetch {
      isFetchSuspended = true
      await withCheckedContinuation { continuation in fetchContinuation = continuation }
      isFetchSuspended = false
    }
    return stubbedTasks
  }
  func observe() -> AsyncStream<[TaskItem]>? { nil }

  /// Resumes a fetch suspended by ``suspendFetch``.
  func resumeFetch() {
    fetchContinuation?.resume()
    fetchContinuation = nil
  }
}

private func makeItem(
  providerID: ProviderID = "alpha", nativeID: String = UUID().uuidString, title: String,
  priority: TaskPriority = .none
) -> TaskItem {
  TaskItem(
    id: TaskRef(providerID: providerID, nativeID: nativeID),
    title: title,
    notes: nil,
    format: .plainText,
    priority: priority,
    dueDate: nil,
    scheduledDate: nil,
    startDate: nil,
    list: nil,
    section: nil,
    sourceURL: nil,
    completedAt: nil,
    createdAt: nil
  )
}

/// Groups an isolated ``TimerSearchPresenter`` with the fake provider and stores tests mutate.
@MainActor
private struct Subjects {
  let presenter: TimerSearchPresenter
  let provider: SearchStubProvider
  let registry: ProviderRegistry
  let settings: AppSettings
  let activeTaskStore: ActiveTaskStore
}

private struct WaitTimedOutError: Error {}

// MARK: - Tests

@Suite("TimerSearchPresenter")
@MainActor
struct TimerSearchPresenterTests {

  private func makeSubjects(tasks: [TaskItem] = []) -> Subjects {
    let settingsStore = SettingsStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
    let settings = AppSettings(store: settingsStore)
    let activeTaskStore = ActiveTaskStore(store: settingsStore)
    let registry = ProviderRegistry(store: settingsStore)
    let provider = SearchStubProvider(id: "alpha", tasks: tasks)
    registry.register(provider)
    registry.enable(provider)
    let queryService = TaskQueryService(registry: registry, sorter: TaskSorter())
    let presenter = TimerSearchPresenter(
      queryService: queryService, settings: settings, activeTaskStore: activeTaskStore,
      registry: registry)
    return Subjects(
      presenter: presenter, provider: provider, registry: registry, settings: settings,
      activeTaskStore: activeTaskStore)
  }

  /// Polls `condition` until it's `true` or `timeout` elapses, throwing on timeout — used instead
  /// of a fixed sleep so a fetch's actual completion (250 ms debounce plus scheduling) does not
  /// race the assertion under a loaded, fully-parallel test run.
  private func waitUntil(
    timeout: Duration = .seconds(5), _ condition: () -> Bool
  ) async throws {
    let deadline = ContinuousClock.now.advanced(by: timeout)
    while !condition() {
      guard ContinuousClock.now < deadline else { throw WaitTimedOutError() }
      try await Task.sleep(for: .milliseconds(20))
    }
  }

  // MARK: - queryChanged

  @Test func emptyOrWhitespaceQueryClearsResultsAndCancelsPendingWork() async throws {
    let subjects = makeSubjects(tasks: [makeItem(title: "Write tests")])
    subjects.presenter.queryChanged("write")
    subjects.presenter.queryChanged("   ")

    #expect(subjects.presenter.results.isEmpty)
    #expect(subjects.presenter.isSearching == false)

    // The cancelled fetch never lands even after its debounce interval would have elapsed —
    // there is nothing to poll for, so this waits out a generous fixed margin instead.
    try await Task.sleep(for: .milliseconds(600))
    #expect(subjects.presenter.results.isEmpty)
    #expect(subjects.presenter.isSearching == false)
  }

  @Test func queryReturnsTitleMatchingTasksSortedPerSettings() async throws {
    let subjects = makeSubjects(tasks: [
      makeItem(title: "Write tests", priority: .low),
      makeItem(title: "Write docs", priority: .high),
      makeItem(title: "Review PR", priority: .medium),
    ])
    subjects.settings.taskSortField = .priority
    subjects.settings.taskSortDirection = .descending

    subjects.presenter.queryChanged("write")
    try await waitUntil { !subjects.presenter.results.isEmpty }

    #expect(subjects.presenter.results.map(\.title) == ["Write docs", "Write tests"])
  }

  @Test func staleResponseForOlderQueryIsDiscardedAndLeavesIsSearchingTrue() async throws {
    let subjects = makeSubjects(tasks: [makeItem(title: "Write tests")])
    subjects.provider.suspendFetch = true
    subjects.presenter.queryChanged("write")
    try await waitUntil { subjects.provider.isFetchSuspended }
    #expect(subjects.presenter.isSearching)

    // A newer query lands before the in-flight fetch for "write" resolves.
    subjects.presenter.query = "write more"
    subjects.provider.resumeFetch()
    try await waitUntil { !subjects.provider.isFetchSuspended }

    #expect(subjects.presenter.results.isEmpty)
    #expect(subjects.presenter.isSearching)
  }

  @Test func newResultSetResetsHighlightedIndexToZero() async throws {
    let subjects = makeSubjects(tasks: [
      makeItem(title: "Write tests"), makeItem(title: "Write docs"),
    ])
    subjects.presenter.queryChanged("write")
    try await waitUntil { subjects.presenter.results.count == 2 }

    // Simulates a hover moving the highlight under the old query's result set.
    subjects.presenter.highlightedIndex = 1
    subjects.provider.stubbedTasks = [makeItem(title: "Write more")]
    subjects.presenter.queryChanged("write more")
    try await waitUntil { subjects.presenter.results.map(\.title) == ["Write more"] }

    #expect(subjects.presenter.highlightedIndex == 0)
  }

  @Test func inFlightFetchKeepsPreviousResultsUntilSettled() async throws {
    let subjects = makeSubjects(tasks: [makeItem(title: "Write tests")])
    subjects.presenter.queryChanged("write")
    try await waitUntil { subjects.presenter.results.count == 1 }

    subjects.provider.suspendFetch = true
    subjects.provider.stubbedTasks = [
      makeItem(title: "Write docs again"), makeItem(title: "Write more again"),
    ]
    subjects.presenter.queryChanged("again")
    try await waitUntil { subjects.provider.isFetchSuspended }
    // Stale rows stay on screen while the refetch is in flight.
    #expect(subjects.presenter.results.map(\.title) == ["Write tests"])
    #expect(subjects.presenter.isSearching)

    subjects.provider.resumeFetch()
    try await waitUntil { subjects.presenter.isSearching == false }
    #expect(subjects.presenter.results.map(\.title) == ["Write docs again", "Write more again"])
  }

  // MARK: - track / clear

  @Test func trackSetsActiveTaskClearsStagedTaskAndResetsSearch() async throws {
    let subjects = makeSubjects(tasks: [makeItem(title: "Write tests")])
    subjects.activeTaskStore.stage(makeItem(title: "Staged task"))
    subjects.presenter.queryChanged("write")
    try await waitUntil { !subjects.presenter.results.isEmpty }
    let task = try #require(subjects.presenter.results.first)

    subjects.presenter.track(task)

    #expect(subjects.activeTaskStore.activeTask == task)
    #expect(subjects.activeTaskStore.stagedTask == nil)
    #expect(subjects.presenter.query.isEmpty)
    #expect(subjects.presenter.results.isEmpty)
  }

  @Test func trackDoesNotPauseTheEngine() async throws {
    let subjects = makeSubjects(tasks: [makeItem(title: "Write tests")])
    let engine = SessionEngine()
    engine.start(phase: .focus)
    let runningState = engine.state

    subjects.presenter.queryChanged("write")
    try await waitUntil { !subjects.presenter.results.isEmpty }
    let task = try #require(subjects.presenter.results.first)
    subjects.presenter.track(task)

    #expect(engine.state == runningState)
  }

  @Test func clearFullyResetsStateAndCancelsPendingWork() async throws {
    let subjects = makeSubjects(tasks: [makeItem(title: "Write tests")])
    subjects.provider.suspendFetch = true
    subjects.presenter.queryChanged("write")
    try await waitUntil { subjects.provider.isFetchSuspended }

    subjects.presenter.clear()

    #expect(subjects.presenter.query.isEmpty)
    #expect(subjects.presenter.results.isEmpty)
    #expect(subjects.presenter.highlightedIndex == 0)
    #expect(subjects.presenter.isSearching == false)

    // The in-flight fetch's eventual response is discarded by the stale guard.
    subjects.provider.resumeFetch()
    try await waitUntil { !subjects.provider.isFetchSuspended }
    #expect(subjects.presenter.results.isEmpty)
    #expect(subjects.presenter.isSearching == false)
  }

  // MARK: - Highlight movement

  @Test func moveHighlightClampsAtBothEnds() async throws {
    let subjects = makeSubjects(tasks: [
      makeItem(title: "Write tests"), makeItem(title: "Write docs"), makeItem(title: "Write more"),
    ])
    subjects.presenter.queryChanged("write")
    try await waitUntil { subjects.presenter.results.count == 3 }

    subjects.presenter.moveHighlight(by: -1)
    #expect(subjects.presenter.highlightedIndex == 0)

    subjects.presenter.moveHighlight(by: 1)
    subjects.presenter.moveHighlight(by: 1)
    subjects.presenter.moveHighlight(by: 1)
    #expect(subjects.presenter.highlightedIndex == 2)
  }

  @Test func trackHighlightedIsNoOpOnEmptyResults() {
    let subjects = makeSubjects()
    subjects.presenter.trackHighlighted()
    #expect(subjects.activeTaskStore.activeTask == nil)
  }
}
