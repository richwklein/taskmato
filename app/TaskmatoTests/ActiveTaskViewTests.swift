//
//  ActiveTaskViewTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

// MARK: - Fakes

/// A controllable stand-in for a closable provider, mirroring `TaskProviderTests`'s
/// `FakeClosableProvider` with a switchable failure so the complete gesture's error path is
/// testable too.
private final class FakeClosableProvider: ClosableTaskProvider {
  let id: ProviderID = "fake-closable"
  let displayName = "Fake Closable"
  let icon = "square"
  let entitlement: ProviderEntitlement = .free

  var completeError: (any Error)?
  private(set) var completedRefs: [TaskRef] = []

  func authorize() async throws {}
  func lists() async throws -> [TaskList] { [] }
  func tasks(in _: TaskList?) async throws -> [TaskItem] { [] }
  func observe() -> AsyncStream<[TaskItem]>? { nil }

  func complete(_ ref: TaskRef) async throws {
    if let completeError { throw completeError }
    completedRefs.append(ref)
  }
  func reopen(_ ref: TaskRef) async throws {}
}

private struct StubError: Error {}

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

// MARK: - Test context

/// Every collaborator a real `ActiveTaskView` needs, wired over one isolated `UserDefaults`
/// suite (mirrors `MainNavigationTests`'s `NavContext`). `ActiveTaskView` is a plain struct with
/// no rendering dependency, so its gesture methods — made non-`private` for exactly this reason
/// — can be exercised directly without hosting the view.
@MainActor
private struct ViewContext {
  let engine: SessionEngine
  let selectionStore: TaskSelectionStore
  let registry: ProviderRegistry
  let provider: FakeClosableProvider
  let nav: MainNavigation
  let errorPresenter: ErrorPresenter

  func view(style: ActiveTaskStyle = .detail) -> ActiveTaskView {
    ActiveTaskView(
      engine: engine, selectionStore: selectionStore, registry: registry, nav: nav,
      errorPresenter: errorPresenter, style: style, onSelect: nil)
  }
}

@MainActor
private func makeContext() -> ViewContext {
  let settingsStore = SettingsStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
  let engine = SessionEngine()
  let selectionStore = TaskSelectionStore(store: settingsStore)
  let registry = ProviderRegistry(store: settingsStore)
  let provider = FakeClosableProvider()
  registry.register(provider)
  let settings = AppSettings(store: settingsStore)
  let sidebarSelection = SelectionStore(registry: registry, store: settingsStore)
  let nav = MainNavigation(
    settings: settings, selectionStore: sidebarSelection, statsViewModel: .preview,
    store: settingsStore)
  return ViewContext(
    engine: engine, selectionStore: selectionStore, registry: registry, provider: provider,
    nav: nav, errorPresenter: ErrorPresenter())
}

/// `true` while `state` is `.paused`, regardless of phase or remaining time.
private func isPaused(_ state: SessionState) -> Bool {
  if case .paused = state { return true }
  return false
}

/// Yields the main-actor executor repeatedly, giving the `Task` a gesture spawns for its async
/// provider call a chance to complete before assertions run (mirrors `PhaseOrchestratorTests`).
@MainActor
private func drain() async {
  for _ in 0..<20 { await Task.yield() }
}

// MARK: - Tests

/// Exercises the D-e/D-f gesture matrix extracted from `ActiveTaskView`'s complete, swap, and
/// clear actions (design doc 0010, D2/D3/D10; design doc "stage the next focus", D-e/D-f).
@Suite("ActiveTaskView gestures")
@MainActor
struct ActiveTaskViewTests {

  // MARK: - Swap

  @Test func swapDuringFocusPausesAndMarksAContinuation() {
    let ctx = makeContext()
    let task = makeItem(providerID: "fake-closable", nativeID: "1", title: "Write plan")
    ctx.selectionStore.select(task)
    ctx.engine.start(phase: .focus)

    ctx.view().swapTapped()

    #expect(isPaused(ctx.engine.state))
    #expect(ctx.selectionStore.isPendingContinuation)
  }

  @Test func swapDuringBreakDoesNotPauseOrMarkAContinuation() {
    let ctx = makeContext()
    let task = makeItem(providerID: "fake-closable", nativeID: "1", title: "Write plan")
    ctx.selectionStore.select(task)
    ctx.engine.start(phase: .shortBreak)

    ctx.view().swapTapped()

    #expect(ctx.engine.isRunning)
    #expect(!ctx.selectionStore.isPendingContinuation)
  }

  @Test func swapAlwaysDropsAStagedTask() {
    let ctx = makeContext()
    let active = makeItem(providerID: "fake-closable", nativeID: "1", title: "Active")
    let staged = makeItem(providerID: "fake-closable", nativeID: "2", title: "Staged")
    ctx.selectionStore.select(active)
    ctx.selectionStore.stage(staged)
    ctx.engine.start(phase: .shortBreak)  // the no-pause branch still drops staging

    ctx.view().swapTapped()

    #expect(ctx.selectionStore.stagedTask == nil)
    #expect(ctx.selectionStore.activeTask == active)  // swap itself never changes the active task
  }

  // MARK: - Clear

  @Test func clearDuringFocusPausesAndClosesTheSlice() {
    let ctx = makeContext()
    let task = makeItem(providerID: "fake-closable", nativeID: "1", title: "Write plan")
    ctx.selectionStore.select(task)
    ctx.engine.start(phase: .focus)

    ctx.view().clearTapped()

    #expect(isPaused(ctx.engine.state))
    #expect(ctx.selectionStore.activeTask == nil)
    #expect(ctx.selectionStore.isPendingContinuation)
  }

  @Test func clearWhileIdleOnlyDetaches() {
    let ctx = makeContext()
    let task = makeItem(providerID: "fake-closable", nativeID: "1", title: "Write plan")
    ctx.selectionStore.select(task)

    ctx.view().clearTapped()

    #expect(ctx.engine.state == .idle)
    #expect(ctx.selectionStore.activeTask == nil)
    #expect(!ctx.selectionStore.isPendingContinuation)
  }

  @Test func clearAlwaysDropsAStagedTask() {
    let ctx = makeContext()
    let active = makeItem(providerID: "fake-closable", nativeID: "1", title: "Active")
    let staged = makeItem(providerID: "fake-closable", nativeID: "2", title: "Staged")
    ctx.selectionStore.select(active)
    ctx.selectionStore.stage(staged)

    ctx.view().clearTapped()

    #expect(ctx.selectionStore.stagedTask == nil)
  }

  // MARK: - Complete, no staged task (unchanged D2/D3/D10 behavior)

  @Test func completeDuringFocusPausesThenClearsOnSuccess() async {
    let ctx = makeContext()
    let task = makeItem(providerID: "fake-closable", nativeID: "1", title: "Write plan")
    ctx.selectionStore.select(task)
    ctx.engine.start(phase: .focus)
    ctx.nav.destination = .timer

    ctx.view().completeTapped(task)
    #expect(isPaused(ctx.engine.state))  // pauses synchronously, before the provider call
    await drain()

    #expect(ctx.provider.completedRefs == [task.id])
    #expect(ctx.selectionStore.activeTask == nil)
    #expect(ctx.selectionStore.isPendingContinuation)
    #expect(ctx.nav.destination != .timer)  // routed to Tasks
  }

  @Test func completeDuringFocusResumesAndSurfacesTheErrorOnFailure() async {
    let ctx = makeContext()
    let task = makeItem(providerID: "fake-closable", nativeID: "1", title: "Write plan")
    ctx.selectionStore.select(task)
    ctx.engine.start(phase: .focus)
    ctx.provider.completeError = StubError()

    ctx.view().completeTapped(task)
    await drain()

    #expect(ctx.engine.isRunning)
    #expect(ctx.selectionStore.activeTask == task)
    #expect(ctx.errorPresenter.current != nil)
  }

  @Test func completeDuringBreakOnlyMutatesSelection() async {
    let ctx = makeContext()
    let task = makeItem(providerID: "fake-closable", nativeID: "1", title: "Write plan")
    ctx.selectionStore.select(task)
    ctx.engine.start(phase: .shortBreak)

    ctx.view().completeTapped(task)
    await drain()

    #expect(ctx.engine.isRunning)
    #expect(ctx.selectionStore.activeTask == nil)
    #expect(!ctx.selectionStore.isPendingContinuation)
  }

  // MARK: - Complete with a staged task (D-f)

  @Test func completeDuringFocusWithAStagedTaskPromotesDirectly() async {
    let ctx = makeContext()
    let active = makeItem(providerID: "fake-closable", nativeID: "1", title: "Active")
    let staged = makeItem(providerID: "fake-closable", nativeID: "2", title: "Staged")
    ctx.selectionStore.select(active)
    ctx.selectionStore.stage(staged)
    ctx.engine.start(phase: .focus)
    var promoted = false
    ctx.selectionStore.onStagedPromotion = { promoted = true }

    ctx.view().completeTapped(active)
    await drain()

    #expect(ctx.selectionStore.activeTask == staged)
    #expect(ctx.selectionStore.stagedTask == nil)
    #expect(promoted)
    #expect(!ctx.selectionStore.isPendingContinuation)
  }

  @Test func completeDuringFocusWithAStagedTaskSkipsRoutingToTasks() async {
    let ctx = makeContext()
    let active = makeItem(providerID: "fake-closable", nativeID: "1", title: "Active")
    let staged = makeItem(providerID: "fake-closable", nativeID: "2", title: "Staged")
    ctx.selectionStore.select(active)
    ctx.selectionStore.stage(staged)
    ctx.engine.start(phase: .focus)
    ctx.nav.destination = .timer

    ctx.view().completeTapped(active)
    await drain()

    #expect(ctx.nav.destination == .timer)  // never routed away
  }

  @Test func completeDuringBreakWithAStagedTaskPromotesDirectly() async {
    let ctx = makeContext()
    let active = makeItem(providerID: "fake-closable", nativeID: "1", title: "Active")
    let staged = makeItem(providerID: "fake-closable", nativeID: "2", title: "Staged")
    ctx.selectionStore.select(active)
    ctx.selectionStore.stage(staged)
    ctx.engine.start(phase: .shortBreak)

    ctx.view().completeTapped(active)
    await drain()

    #expect(ctx.selectionStore.activeTask == staged)
    #expect(ctx.selectionStore.stagedTask == nil)
  }

  @Test func completeWhileIdleWithAStagedTaskPromotesDirectly() async {
    let ctx = makeContext()
    let active = makeItem(providerID: "fake-closable", nativeID: "1", title: "Active")
    let staged = makeItem(providerID: "fake-closable", nativeID: "2", title: "Staged")
    ctx.selectionStore.select(active)
    ctx.selectionStore.stage(staged)

    ctx.view().completeTapped(active)
    await drain()

    #expect(ctx.selectionStore.activeTask == staged)
    #expect(ctx.selectionStore.stagedTask == nil)
  }
}
