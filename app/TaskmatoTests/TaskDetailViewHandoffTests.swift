//
//  TaskDetailViewHandoffTests.swift
//  TaskmatoTests
//

import Foundation
import Testing
import UserNotifications

@testable import Taskmato

// MARK: - Fakes

private final class FakeNotificationCenter: NotificationCenterAPI {
  func authorizationStatus() async -> UNAuthorizationStatus { .authorized }

  func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool { true }

  func scheduleNotification(_ request: UNNotificationRequest) {}

  func setDelegate(_ delegate: (any UNUserNotificationCenterDelegate)?) {}
}

/// A manually advanced clock shared by the engine and the orchestrator.
@MainActor
private final class TestClock {
  var date = Date(timeIntervalSinceReferenceDate: 1_000_000)

  func now() -> Date { date }

  func advance(_ seconds: TimeInterval) { date = date.addingTimeInterval(seconds) }
}

// MARK: - Test context

/// A real `TaskDetailView` over the production wiring that matters for crediting: a real engine
/// on a controllable clock, a running `PhaseOrchestrator`, `FocusAttribution`, and the
/// focus-handoff callbacks wired as `AppComposition.wireFocusHandoff` does.
@MainActor
private struct HandoffContext {
  let clock: TestClock
  let engine: SessionEngine
  let settings: AppSettings
  let activeTaskStore: ActiveTaskStore
  let store: SessionStore
  let presenter: TimerPresenter
  let view: TaskDetailView
}

@MainActor
private func makeHandoffContext() async -> HandoffContext {
  let clock = TestClock()
  let settingsStore = SettingsStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
  let engine = SessionEngine(now: { clock.now() })
  let settings = AppSettings(store: settingsStore)
  settings.startFocusOnTaskPick = true
  let activeTaskStore = ActiveTaskStore(store: settingsStore)
  let registry = ProviderRegistry(store: settingsStore)
  let sidebarSelection = SelectionStore(registry: registry, store: settingsStore)
  let nav = MainNavigation(
    settings: settings, selectionStore: sidebarSelection, statsViewModel: .preview,
    store: settingsStore)
  let presenter = TimerPresenter(
    engine: engine, settings: settings, activeTaskStore: activeTaskStore)
  let store = SessionStore(repository: FakeSessionRepository())
  let attribution = FocusAttribution()
  let notifications = NotificationService(settings: settings, center: FakeNotificationCenter())
  await notifications.refreshAuthStatus()
  let orchestrator = PhaseOrchestrator(
    events: engine.phaseEvents, engine: engine, store: store, settings: settings,
    activeTaskStore: activeTaskStore, notifications: notifications, attribution: attribution,
    now: { clock.now() })
  Task { await orchestrator.run() }

  let coordinator = FocusHandoffCoordinator(presenter: presenter, settings: settings)
  activeTaskStore.onActiveTaskChanged = { [weak engine] task in
    guard let engine else { return }
    attribution.taskChanged(to: task, consumedSeconds: engine.consumedFocusSeconds)
  }
  activeTaskStore.onContinuationSelect = { _ = coordinator.resumeAfterHandoff() }
  activeTaskStore.onStagedPromotion = { coordinator.resumeAfterHandoff() }
  activeTaskStore.onTaskPicked = { coordinator.startFocusOnPick() }

  let view = TaskDetailView(
    activeTaskStore: activeTaskStore, registry: registry,
    queryService: TaskQueryService(registry: registry, sorter: TaskSorter()),
    destinationResolver: TaskDestinationResolver(registry: registry, settings: settings),
    sidebarSelection: sidebarSelection, nav: nav, settings: settings,
    errorPresenter: ErrorPresenter(), presenter: presenter)
  return HandoffContext(
    clock: clock, engine: engine, settings: settings, activeTaskStore: activeTaskStore,
    store: store, presenter: presenter, view: view)
}

private func makeItem(title: String) -> TaskItem {
  TaskItem(
    id: TaskRef(providerID: "alpha", nativeID: title),
    title: title, notes: nil, format: .plainText, priority: .none, dueDate: nil,
    scheduledDate: nil, startDate: nil, list: nil, section: nil, sourceURL: nil,
    completedAt: nil, createdAt: nil)
}

/// Yields the main-actor executor so the orchestrator drains buffered engine events.
@MainActor
private func drain() async {
  for _ in 0..<20 { await Task.yield() }
}

extension HandoffContext {
  /// Tracks `task`, runs 100 s of focus on it, and pauses — the state a complete, swap or clear
  /// hands off from.
  fileprivate func pausedFocus(on task: TaskItem) async {
    activeTaskStore.track(task)
    await drain()
    clock.advance(100)
    presenter.pause()
  }
}

// MARK: - Tests

/// Covers the leftover submenu's "Use Time Left" and "Start Fresh" sequences, including the
/// crediting of the paused phase's partial time, which depends on the order of stop, stage and start.
@MainActor
struct TaskDetailViewHandoffTests {

  @Test func startFreshAfterASwapCreditsThePartialSessionToTheOldTask() async {
    let ctx = await makeHandoffContext()
    let old = makeItem(title: "Old")
    let new = makeItem(title: "New")
    await ctx.pausedFocus(on: old)
    ctx.activeTaskStore.markPendingContinuation()

    ctx.view.startFresh(new, minutes: 15)
    await drain()

    #expect(ctx.store.sessions.count == 1)
    let segments = ctx.store.sessions.first?.segments ?? []
    #expect(segments.map(\.taskTitle) == ["Old"])
    #expect(segments.map(\.seconds) == [100])
    guard case .running(.focus, _, let duration) = ctx.engine.state else {
      Issue.record("Expected a running focus phase, got \(ctx.engine.state)")
      return
    }
    #expect(duration == 15 * 60)
    #expect(ctx.activeTaskStore.activeTask == new)
    #expect(ctx.activeTaskStore.stagedTask == nil)
  }

  @Test func startFreshAfterACompleteCreditsThePartialSessionToTheCompletedTask() async {
    let ctx = await makeHandoffContext()
    let done = makeItem(title: "Done")
    let new = makeItem(title: "New")
    await ctx.pausedFocus(on: done)
    ctx.activeTaskStore.clearActiveTask()
    ctx.activeTaskStore.markPendingContinuation()

    ctx.view.startFresh(new, minutes: 15)
    await drain()

    let credited = (ctx.store.sessions.first?.segments ?? []).filter { $0.seconds > 0 }
    #expect(credited.map(\.taskTitle) == ["Done"])
    guard case .running(.focus, _, let duration) = ctx.engine.state else {
      Issue.record("Expected a running focus phase, got \(ctx.engine.state)")
      return
    }
    #expect(duration == 15 * 60)
    #expect(ctx.activeTaskStore.activeTask == new)
  }

  @Test func useTimeLeftResumesTheRemainderOnTheNewTaskEvenWithPickToStartOff() async {
    let ctx = await makeHandoffContext()
    ctx.settings.startFocusOnTaskPick = false
    let old = makeItem(title: "Old")
    let new = makeItem(title: "New")
    ctx.activeTaskStore.track(old)
    ctx.presenter.start()
    await drain()
    ctx.clock.advance(100)
    ctx.presenter.pause()
    ctx.activeTaskStore.markPendingContinuation()

    ctx.view.useTimeLeft(new)

    #expect(ctx.engine.isRunning)
    #expect(ctx.engine.timeRemaining == 1400)
    #expect(ctx.activeTaskStore.activeTask == new)
  }

  @Test func useTimeLeftStartsTheTaskWhenAStopClearedTheContinuation() async {
    let ctx = await makeHandoffContext()
    await ctx.pausedFocus(on: makeItem(title: "Old"))
    ctx.activeTaskStore.markPendingContinuation()
    ctx.presenter.stop()
    let new = makeItem(title: "New")

    ctx.view.useTimeLeft(new)

    guard case .running(.focus, _, let duration) = ctx.engine.state else {
      Issue.record("Expected a running focus phase, got \(ctx.engine.state)")
      return
    }
    #expect(duration == TimeInterval(ctx.settings.focusMinutes * 60))
    #expect(ctx.activeTaskStore.activeTask == new)
  }

  @Test func useTimeLeftStagesTheTaskWhenASkipClearedTheContinuation() async {
    let ctx = await makeHandoffContext()
    await ctx.pausedFocus(on: makeItem(title: "Old"))
    ctx.activeTaskStore.markPendingContinuation()
    ctx.presenter.skip()
    let new = makeItem(title: "New")

    ctx.view.useTimeLeft(new)

    #expect(ctx.engine.state != .idle)
    #expect(ctx.activeTaskStore.stagedTask == new)
    #expect(ctx.activeTaskStore.activeTask?.title == "Old")
  }

  @Test func useTimeLeftStagesTheTaskWhenAResumeClearedTheContinuation() async {
    let ctx = await makeHandoffContext()
    await ctx.pausedFocus(on: makeItem(title: "Old"))
    ctx.activeTaskStore.markPendingContinuation()
    ctx.presenter.resume()
    let new = makeItem(title: "New")

    ctx.view.useTimeLeft(new)

    #expect(ctx.engine.isRunning)
    #expect(ctx.activeTaskStore.stagedTask == new)
    #expect(ctx.activeTaskStore.activeTask?.title == "Old")
  }

  @Test func resumeIsInertAfterACompleteSoTheContinuationSurvives() async {
    let ctx = await makeHandoffContext()
    await ctx.pausedFocus(on: makeItem(title: "Done"))
    ctx.activeTaskStore.clearActiveTask()
    ctx.activeTaskStore.markPendingContinuation()

    ctx.presenter.resume()

    #expect(ctx.engine.isRunning == false)
    #expect(ctx.presenter.pendingContinuationRemaining != nil)
  }

  @Test func startFreshDoesNotStopAPhaseAnotherSurfaceResumed() async {
    let ctx = await makeHandoffContext()
    let old = makeItem(title: "Old")
    await ctx.pausedFocus(on: old)
    ctx.activeTaskStore.markPendingContinuation()
    ctx.presenter.resume()
    let new = makeItem(title: "New")

    ctx.view.startFresh(new, minutes: 15)
    await drain()

    #expect(ctx.engine.isRunning)
    #expect(ctx.store.sessions.isEmpty)
    #expect(ctx.activeTaskStore.activeTask == old)
    #expect(ctx.activeTaskStore.stagedTask == new)
  }
}
