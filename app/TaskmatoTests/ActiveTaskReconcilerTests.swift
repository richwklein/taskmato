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

  init(id: ProviderID, tasks: [TaskItem] = []) {
    self.id = id
    self.displayName = id.rawValue
    self.stubbedTasks = tasks
  }

  func authorize() async throws {}
  func lists() async throws -> [TaskList] { [] }
  func tasks(in _: TaskList?) async throws -> [TaskItem] {
    if shouldThrow { throw StubReconcilerError() }
    return stubbedTasks
  }
  func observe() -> AsyncStream<[TaskItem]>? { nil }
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
}
