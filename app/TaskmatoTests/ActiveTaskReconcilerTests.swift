//
//  ActiveTaskReconcilerTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

// MARK: - Fakes

@MainActor
private final class ReconcilerStubProvider: TaskProvider {
  let id: ProviderID
  let displayName: String
  let icon: String = "square"
  let entitlement: ProviderEntitlement = .free
  var stubbedTasks: [TaskItem]
  var shouldThrow = false
  var isAuthorized = true

  /// When `true`, `tasks(in:)` suspends until ``resumeFetch()`` is called — used to land another
  /// mutation in the window between the fetch and this reconcile pass observing its result.
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
    if shouldThrow { throw StubReconcilerError() }
    if suspendFetch {
      isFetchSuspended = true
      await withCheckedContinuation { continuation in
        fetchContinuation = continuation
      }
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

private struct StubReconcilerError: Error {}

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

// MARK: - Tests

@Suite("ActiveTaskReconciler")
@MainActor
struct ActiveTaskReconcilerTests {

  private func makeRegistry() -> ProviderRegistry {
    ProviderRegistry(store: SettingsStore(defaults: UserDefaults(suiteName: UUID().uuidString)!))
  }

  private func makeSelectionStore() -> TaskSelectionStore {
    TaskSelectionStore(store: SettingsStore(defaults: UserDefaults(suiteName: UUID().uuidString)!))
  }

  private func registerAndLoad(
    _ provider: ReconcilerStubProvider, in registry: ProviderRegistry
  ) {
    registry.register(provider)
    registry.enable(provider)
    registry.setLists([], forProviderID: provider.id)
  }

  private func makeSUT(
    registry: ProviderRegistry, selectionStore: TaskSelectionStore,
    engine: SessionEngine = SessionEngine(),
    attribution: FocusAttribution = FocusAttribution(),
    errorPresenter: ErrorPresenter = ErrorPresenter()
  ) -> ActiveTaskReconciler {
    ActiveTaskReconciler(
      registry: registry, selectionStore: selectionStore, engine: engine, attribution: attribution,
      errorPresenter: errorPresenter)
  }

  // MARK: - No active task

  @Test func noActiveTaskIsANoOp() async {
    let registry = makeRegistry()
    let selectionStore = makeSelectionStore()
    let sut = makeSUT(registry: registry, selectionStore: selectionStore)
    await sut.reconcile()
    #expect(selectionStore.activeTask == nil)
  }

  // MARK: - Startup / warm-up gating

  @Test func doesNotClearBeforeProviderHasLoaded() async {
    let registry = makeRegistry()
    let provider = ReconcilerStubProvider(id: "alpha", tasks: [])
    registry.register(provider)
    registry.enable(provider)
    // Note: registry.setLists(_:forProviderID:) is never called for "alpha" — simulating a
    // provider that hasn't completed its first load yet.
    let selectionStore = makeSelectionStore()
    let task = makeItem(providerID: "alpha", nativeID: "1", title: "Not yet loaded")
    selectionStore.select(task)

    let sut = makeSUT(registry: registry, selectionStore: selectionStore)
    await sut.reconcile()

    #expect(selectionStore.activeTask == task)
  }

  @Test func clearsOnceProviderHasLoadedAndTaskIsGone() async {
    let registry = makeRegistry()
    let provider = ReconcilerStubProvider(id: "alpha", tasks: [])
    registry.register(provider)
    registry.enable(provider)
    registry.setLists([], forProviderID: "alpha")
    let selectionStore = makeSelectionStore()
    let task = makeItem(providerID: "alpha", nativeID: "1", title: "Deleted task")
    selectionStore.select(task)

    let sut = makeSUT(registry: registry, selectionStore: selectionStore)
    await sut.reconcile()

    #expect(selectionStore.activeTask == nil)
  }

  // MARK: - Disabled provider

  @Test func disabledProviderDoesNotClearActiveTask() async {
    let registry = makeRegistry()
    let provider = ReconcilerStubProvider(id: "alpha", tasks: [])
    registry.register(provider)
    registry.enable(provider)
    registry.setLists([], forProviderID: "alpha")
    let selectionStore = makeSelectionStore()
    let task = makeItem(providerID: "alpha", nativeID: "1", title: "Recoverable task")
    selectionStore.select(task)
    registry.disable(providerID: "alpha")

    let sut = makeSUT(registry: registry, selectionStore: selectionStore)
    await sut.reconcile()

    #expect(selectionStore.activeTask == task)
  }

  @Test func reEnablingRestoresActiveTaskOnceReloaded() async {
    let registry = makeRegistry()
    let task = makeItem(providerID: "alpha", nativeID: "1", title: "Recoverable task")
    let provider = ReconcilerStubProvider(id: "alpha", tasks: [task])
    registry.register(provider)
    registry.enable(provider)
    registry.setLists([], forProviderID: "alpha")
    let selectionStore = makeSelectionStore()
    selectionStore.select(task)
    registry.disable(providerID: "alpha")

    let sut = makeSUT(registry: registry, selectionStore: selectionStore)
    await sut.reconcile()
    #expect(selectionStore.activeTask == task)  // disabled: left untouched

    // Re-enabling alone does not reload the provider (mirrors `AppSidebarView`, which reloads
    // lists on the `enabledIDs` change) — reconciliation only sees it once `setLists` re-fires.
    registry.enable(provider)
    registry.setLists([], forProviderID: "alpha")
    await sut.reconcile()

    #expect(selectionStore.activeTask == task)  // task is still there — restored, not cleared
  }

  // MARK: - Unauthorized provider (issue #547 review: don't mistake "can't read" for "removed")

  @Test func unauthorizedProviderDoesNotClearActiveTask() async {
    let registry = makeRegistry()
    let provider = ReconcilerStubProvider(id: "alpha", tasks: [])
    provider.isAuthorized = false
    registry.register(provider)
    registry.enable(provider)
    registry.setLists([], forProviderID: "alpha")
    let selectionStore = makeSelectionStore()
    let task = makeItem(providerID: "alpha", nativeID: "1", title: "Access revoked")
    selectionStore.select(task)

    let sut = makeSUT(registry: registry, selectionStore: selectionStore)
    await sut.reconcile()

    #expect(selectionStore.activeTask == task)
  }

  // MARK: - Task still present

  @Test func presentTaskIsLeftUntouched() async {
    let registry = makeRegistry()
    let task = makeItem(providerID: "alpha", nativeID: "1", title: "Still here")
    let provider = ReconcilerStubProvider(id: "alpha", tasks: [task])
    registry.register(provider)
    registry.enable(provider)
    registry.setLists([], forProviderID: "alpha")
    let selectionStore = makeSelectionStore()
    selectionStore.select(task)

    let sut = makeSUT(registry: registry, selectionStore: selectionStore)
    await sut.reconcile()

    #expect(selectionStore.activeTask == task)
  }

  @Test func refreshesSnapshotWhenTitleChangedExternally() async {
    let registry = makeRegistry()
    let original = makeItem(providerID: "alpha", nativeID: "1", title: "Old title")
    let updated = makeItem(providerID: "alpha", nativeID: "1", title: "New title")
    let provider = ReconcilerStubProvider(id: "alpha", tasks: [updated])
    registry.register(provider)
    registry.enable(provider)
    registry.setLists([], forProviderID: "alpha")
    let selectionStore = makeSelectionStore()
    selectionStore.select(original)

    let sut = makeSUT(registry: registry, selectionStore: selectionStore)
    await sut.reconcile()

    #expect(selectionStore.activeTask?.title == "New title")
  }

  @Test func refreshingDoesNotFireOnActiveTaskChanged() async {
    let registry = makeRegistry()
    let original = makeItem(providerID: "alpha", nativeID: "1", title: "Old title")
    let updated = makeItem(providerID: "alpha", nativeID: "1", title: "New title")
    let provider = ReconcilerStubProvider(id: "alpha", tasks: [updated])
    registry.register(provider)
    registry.enable(provider)
    registry.setLists([], forProviderID: "alpha")
    let selectionStore = makeSelectionStore()
    selectionStore.select(original)
    var fired = false
    selectionStore.onActiveTaskChanged = { _ in fired = true }

    let sut = makeSUT(registry: registry, selectionStore: selectionStore)
    await sut.reconcile()

    #expect(fired == false)
  }

  // MARK: - Removal: idle (silent)

  @Test func idleRemovalClearsSilently() async {
    let registry = makeRegistry()
    let provider = ReconcilerStubProvider(id: "alpha", tasks: [])
    registry.register(provider)
    registry.enable(provider)
    registry.setLists([], forProviderID: "alpha")
    let selectionStore = makeSelectionStore()
    selectionStore.select(makeItem(providerID: "alpha", nativeID: "1", title: "Gone"))
    let errorPresenter = ErrorPresenter()

    let sut = makeSUT(
      registry: registry, selectionStore: selectionStore, errorPresenter: errorPresenter)
    await sut.reconcile()

    #expect(selectionStore.activeTask == nil)
    #expect(errorPresenter.current == nil)
  }

  // MARK: - Removal: mid-focus (banner)

  @Test func midFocusRemovalPresentsWarningBanner() async {
    let registry = makeRegistry()
    let provider = ReconcilerStubProvider(id: "alpha", tasks: [])
    registry.register(provider)
    registry.enable(provider)
    registry.setLists([], forProviderID: "alpha")
    let selectionStore = makeSelectionStore()
    let task = makeItem(providerID: "alpha", nativeID: "1", title: "Vanished")
    selectionStore.select(task)
    let attribution = FocusAttribution()
    attribution.begin(task: task)
    let errorPresenter = ErrorPresenter()

    let sut = makeSUT(
      registry: registry, selectionStore: selectionStore, attribution: attribution,
      errorPresenter: errorPresenter)
    await sut.reconcile()

    #expect(selectionStore.activeTask == nil)
    #expect(errorPresenter.current?.severity == .warning)
    #expect(errorPresenter.current?.title == "\u{201C}Vanished\u{201D} is not available")
  }

  @Test func runningFocusRemovalPausesTheTimer() async {
    let registry = makeRegistry()
    let provider = ReconcilerStubProvider(id: "alpha", tasks: [])
    registry.register(provider)
    registry.enable(provider)
    registry.setLists([], forProviderID: "alpha")
    let selectionStore = makeSelectionStore()
    let task = makeItem(providerID: "alpha", nativeID: "1", title: "Vanished")
    selectionStore.select(task)
    let engine = SessionEngine()
    engine.start()
    let attribution = FocusAttribution()
    attribution.begin(task: task)

    let sut = makeSUT(
      registry: registry, selectionStore: selectionStore, engine: engine, attribution: attribution)
    await sut.reconcile()

    #expect(selectionStore.activeTask == nil)
    guard case .paused(let phase, _) = engine.state else {
      Issue.record("Expected running focus to pause when its task vanishes")
      return
    }
    #expect(phase == .focus)
  }

  @Test func runningFocusRemovalPresentsWarningEvenBeforeAttributionBegins() async {
    let registry = makeRegistry()
    let provider = ReconcilerStubProvider(id: "alpha", tasks: [])
    registry.register(provider)
    registry.enable(provider)
    registry.setLists([], forProviderID: "alpha")
    let selectionStore = makeSelectionStore()
    let task = makeItem(providerID: "alpha", nativeID: "1", title: "Vanished")
    selectionStore.select(task)
    let engine = SessionEngine()
    engine.start()
    let errorPresenter = ErrorPresenter()

    let sut = makeSUT(
      registry: registry, selectionStore: selectionStore, engine: engine,
      errorPresenter: errorPresenter)
    await sut.reconcile()

    #expect(selectionStore.activeTask == nil)
    #expect(errorPresenter.current?.severity == .warning)
    #expect(errorPresenter.current?.title == "\u{201C}Vanished\u{201D} is not available")
  }

  @Test func runningBreakRemovalDoesNotPauseTheTimer() async {
    let registry = makeRegistry()
    let provider = ReconcilerStubProvider(id: "alpha", tasks: [])
    registry.register(provider)
    registry.enable(provider)
    registry.setLists([], forProviderID: "alpha")
    let selectionStore = makeSelectionStore()
    let task = makeItem(providerID: "alpha", nativeID: "1", title: "Vanished")
    selectionStore.select(task)
    let engine = SessionEngine()
    engine.start(phase: .shortBreak)

    let sut = makeSUT(registry: registry, selectionStore: selectionStore, engine: engine)
    await sut.reconcile()

    #expect(selectionStore.activeTask == nil)
    guard case .running(let phase, _, _) = engine.state else {
      Issue.record("Expected running break to keep running")
      return
    }
    #expect(phase == .shortBreak)
  }

  // MARK: - Transient fetch failure

  @Test func fetchFailureDoesNotClearActiveTask() async {
    let registry = makeRegistry()
    let provider = ReconcilerStubProvider(id: "alpha", tasks: [])
    provider.shouldThrow = true
    registry.register(provider)
    registry.enable(provider)
    registry.setLists([], forProviderID: "alpha")
    let selectionStore = makeSelectionStore()
    let task = makeItem(providerID: "alpha", nativeID: "1", title: "Unverifiable")
    selectionStore.select(task)

    let sut = makeSUT(registry: registry, selectionStore: selectionStore)
    await sut.reconcile()

    #expect(selectionStore.activeTask == task)
  }

  // MARK: - Staged leg: own provider gate

  @Test func stagedLegRunsWithNoActiveTaskAtAll() async {
    let registry = makeRegistry()
    let provider = ReconcilerStubProvider(id: "alpha", tasks: [])
    registerAndLoad(provider, in: registry)
    let selectionStore = makeSelectionStore()
    selectionStore.stage(makeItem(providerID: "alpha", nativeID: "1", title: "Gone"))

    let sut = makeSUT(registry: registry, selectionStore: selectionStore)
    await sut.reconcile()

    #expect(selectionStore.stagedTask == nil)
  }

  @Test func stagedLegRunsWhenStagedProviderDiffersFromActiveProvider() async {
    let registry = makeRegistry()
    let activeProvider = ReconcilerStubProvider(
      id: "local", tasks: [makeItem(providerID: "local", nativeID: "1", title: "Active")])
    let stagedProvider = ReconcilerStubProvider(id: "reminders", tasks: [])
    registerAndLoad(activeProvider, in: registry)
    registerAndLoad(stagedProvider, in: registry)
    let selectionStore = makeSelectionStore()
    selectionStore.select(makeItem(providerID: "local", nativeID: "1", title: "Active"))
    selectionStore.stage(makeItem(providerID: "reminders", nativeID: "1", title: "Gone"))

    let sut = makeSUT(registry: registry, selectionStore: selectionStore)
    // Simulate the reload that fired for the *staged* task's own provider. Today's bug keys the
    // staged leg's gate off the active task's provider ("local"), so this call — which should
    // reach the staged task — would incorrectly bail before ever looking at it.
    await sut.reconcile(changedProviderID: "reminders")

    #expect(selectionStore.stagedTask == nil)
    #expect(selectionStore.activeTask?.title == "Active")
  }

  // MARK: - Staged leg: vanished (silent)

  @Test func vanishedStagedTaskClearsSilently() async {
    let registry = makeRegistry()
    let provider = ReconcilerStubProvider(id: "alpha", tasks: [])
    registerAndLoad(provider, in: registry)
    let selectionStore = makeSelectionStore()
    selectionStore.stage(makeItem(providerID: "alpha", nativeID: "1", title: "Gone"))
    let engine = SessionEngine()
    engine.start(phase: .shortBreak)
    let errorPresenter = ErrorPresenter()

    let sut = makeSUT(
      registry: registry, selectionStore: selectionStore, engine: engine,
      errorPresenter: errorPresenter)
    await sut.reconcile()

    #expect(selectionStore.stagedTask == nil)
    #expect(errorPresenter.current == nil)
    guard case .running(let phase, _, _) = engine.state else {
      Issue.record("Expected the break to keep running")
      return
    }
    #expect(phase == .shortBreak)
  }

  // MARK: - Staged leg: renamed (refreshes in place)

  @Test func renamedStagedTaskRefreshesInPlace() async {
    let registry = makeRegistry()
    let original = makeItem(providerID: "alpha", nativeID: "1", title: "Old title")
    let updated = makeItem(providerID: "alpha", nativeID: "1", title: "New title")
    let provider = ReconcilerStubProvider(id: "alpha", tasks: [updated])
    registerAndLoad(provider, in: registry)
    let selectionStore = makeSelectionStore()
    selectionStore.stage(original)

    let sut = makeSUT(registry: registry, selectionStore: selectionStore)
    await sut.reconcile()

    #expect(selectionStore.stagedTask?.title == "New title")
  }

  // MARK: - Staged leg: case 2, the promotion wins the race

  @Test func promotionWinningTheRaceFallsThroughToActiveVanishedPath() async {
    let registry = makeRegistry()
    let provider = ReconcilerStubProvider(id: "alpha", tasks: [])
    provider.suspendFetch = true
    registerAndLoad(provider, in: registry)
    let selectionStore = makeSelectionStore()
    let task = makeItem(providerID: "alpha", nativeID: "1", title: "Vanished")
    selectionStore.stage(task)
    let engine = SessionEngine()
    engine.start()
    let attribution = FocusAttribution()
    attribution.begin(task: task)
    let errorPresenter = ErrorPresenter()

    let sut = makeSUT(
      registry: registry, selectionStore: selectionStore, engine: engine, attribution: attribution,
      errorPresenter: errorPresenter)

    // Start the reconcile pass; it suspends inside the staged leg's fetch.
    let reconcileTask = Task { await sut.reconcile() }
    while !provider.isFetchSuspended { await Task.yield() }

    // The synchronous promotion at `PhaseOrchestrator.began(.focus)` wins the race: it lands
    // while the fetch above is still in flight. The staged slot empties and the formerly staged
    // task becomes active.
    selectionStore.applyStagedTask()
    #expect(selectionStore.stagedTask == nil)
    #expect(selectionStore.activeTask == task)

    provider.resumeFetch()
    await reconcileTask.value

    #expect(selectionStore.activeTask == nil)
    #expect(errorPresenter.current?.severity == .warning)
    #expect(errorPresenter.current?.title == "\u{201C}Vanished\u{201D} is not available")
    guard case .paused(let phase, _) = engine.state else {
      Issue.record("Expected running focus to pause when its task vanishes")
      return
    }
    #expect(phase == .focus)
  }
}
