//
//  PhaseOrchestratorTests.swift
//  TaskmatoTests
//

import Foundation
import Testing
import UserNotifications

@testable import Taskmato

// MARK: - Fakes

/// A controllable stand-in for UNUserNotificationCenter (spy pattern from NotificationServiceTests).
private final class FakeNotificationCenter: NotificationCenterAPI {
  var stubbedStatus: UNAuthorizationStatus
  private(set) var scheduledRequests: [UNNotificationRequest] = []

  init(status: UNAuthorizationStatus = .authorized) {
    self.stubbedStatus = status
  }

  func authorizationStatus() async -> UNAuthorizationStatus { stubbedStatus }

  func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
    stubbedStatus == .authorized
  }

  func scheduleNotification(_ request: UNNotificationRequest) {
    scheduledRequests.append(request)
  }

  func setDelegate(_ delegate: (any UNUserNotificationCenterDelegate)?) {}
}

// MARK: - Helpers

@MainActor
private struct OrchestratorContext {
  let orchestrator: PhaseOrchestrator
  let continuation: AsyncStream<PhaseEvent>.Continuation
  let engine: SessionEngine
  let store: SessionStore
  let settings: AppSettings
  let activeTaskStore: ActiveTaskStore
  let attribution: FocusAttribution
  let center: FakeNotificationCenter
}

@MainActor
private func makeContext(now: @escaping () -> Date = Date.init) async -> OrchestratorContext {
  let (stream, continuation) = AsyncStream.makeStream(of: PhaseEvent.self)
  let engine = SessionEngine()
  let store = SessionStore(repository: FakeSessionRepository())
  let settingsStore = SettingsStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
  let settings = AppSettings(store: settingsStore)
  let activeTaskStore = ActiveTaskStore(store: settingsStore)
  let attribution = FocusAttribution()
  let center = FakeNotificationCenter(status: .authorized)
  let notifications = NotificationService(settings: settings, center: center)
  await notifications.refreshAuthStatus()
  let orchestrator = PhaseOrchestrator(
    events: stream, engine: engine, store: store, settings: settings,
    activeTaskStore: activeTaskStore, notifications: notifications, attribution: attribution,
    now: now)
  return OrchestratorContext(
    orchestrator: orchestrator, continuation: continuation, engine: engine, store: store,
    settings: settings, activeTaskStore: activeTaskStore, attribution: attribution, center: center)
}

private func makeTask(
  providerID: ProviderID, nativeID: String, title: String
) -> TaskItem {
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
    sourceURL: nil,
    completedAt: nil,
    createdAt: nil
  )
}

/// Yields the main-actor executor repeatedly, giving a concurrently running `Task` a chance to
/// drain buffered `AsyncStream` values before assertions run.
@MainActor
private func drain() async {
  for _ in 0..<20 { await Task.yield() }
}

// MARK: - Tests

@MainActor
struct PhaseOrchestratorTests {

  @Test func completedFocusRecordsSessionNotifiesAndQueuesTheBreak() async {
    let ctx = await makeContext()
    #expect(ctx.center.stubbedStatus == .authorized)
    let runTask = Task { await ctx.orchestrator.run() }

    let startedAt = Date(timeIntervalSinceReferenceDate: 0)
    let endedAt = startedAt.addingTimeInterval(1500)
    ctx.continuation.yield(.began(phase: .focus))
    ctx.continuation.yield(
      .ended(phase: .focus, startedAt: startedAt, endedAt: endedAt, wasCompleted: true))
    await drain()

    #expect(ctx.store.sessions.count == 1)
    #expect(ctx.store.sessions.first?.phase == .focus)
    #expect(ctx.store.sessions.first?.wasCompleted == true)
    #expect(ctx.center.scheduledRequests.count == 1)
    // autoStartBreaks defaults to false — the next phase is queued, not started.
    #expect(ctx.engine.queuedPhase == .shortBreak)
    #expect(ctx.engine.state == .idle)

    ctx.continuation.finish()
    await runTask.value
  }

  @Test func completedFocusAutoStartsBreakWhenEnabled() async {
    let ctx = await makeContext()
    ctx.settings.autoStartBreaks = true
    let runTask = Task { await ctx.orchestrator.run() }

    let startedAt = Date(timeIntervalSinceReferenceDate: 0)
    let endedAt = startedAt.addingTimeInterval(1500)
    ctx.continuation.yield(.began(phase: .focus))
    ctx.continuation.yield(
      .ended(phase: .focus, startedAt: startedAt, endedAt: endedAt, wasCompleted: true))
    await drain()

    guard case .running(let phase, _, _) = ctx.engine.state else {
      Issue.record("Expected the engine to have auto-started the next phase")
      ctx.continuation.finish()
      return
    }
    #expect(phase == .shortBreak)

    ctx.continuation.finish()
    await runTask.value
  }

  @Test func completedBreakAutoStartsFocusWhenATaskIsTracked() async {
    let ctx = await makeContext()
    ctx.settings.autoStartFocus = true
    ctx.activeTaskStore.track(
      makeTask(providerID: "local", nativeID: "abc", title: "Write plan"))
    let runTask = Task { await ctx.orchestrator.run() }

    let startedAt = Date(timeIntervalSinceReferenceDate: 0)
    ctx.continuation.yield(.began(phase: .shortBreak))
    ctx.continuation.yield(
      .ended(
        phase: .shortBreak, startedAt: startedAt, endedAt: startedAt.addingTimeInterval(300),
        wasCompleted: true))
    await drain()

    guard case .running(let phase, _, _) = ctx.engine.state else {
      Issue.record("Expected the engine to have auto-started focus")
      ctx.continuation.finish()
      return
    }
    #expect(phase == .focus)

    ctx.continuation.finish()
    await runTask.value
  }

  @Test func completedBreakQueuesFocusInsteadOfAutoStartingItWithNoTask() async {
    let ctx = await makeContext()
    ctx.settings.autoStartFocus = true
    let runTask = Task { await ctx.orchestrator.run() }

    let startedAt = Date(timeIntervalSinceReferenceDate: 0)
    ctx.continuation.yield(.began(phase: .shortBreak))
    ctx.continuation.yield(
      .ended(
        phase: .shortBreak, startedAt: startedAt, endedAt: startedAt.addingTimeInterval(300),
        wasCompleted: true))
    await drain()

    #expect(ctx.engine.state == .idle)
    #expect(ctx.engine.queuedPhase == .focus)

    ctx.continuation.finish()
    await runTask.value
  }

  @Test func completedBreakAutoStartsFocusForAStagedTask() async {
    let ctx = await makeContext()
    ctx.settings.autoStartFocus = true
    ctx.activeTaskStore.stage(
      makeTask(providerID: "local", nativeID: "abc", title: "Write plan"))
    let runTask = Task { await ctx.orchestrator.run() }

    let startedAt = Date(timeIntervalSinceReferenceDate: 0)
    ctx.continuation.yield(.began(phase: .shortBreak))
    ctx.continuation.yield(
      .ended(
        phase: .shortBreak, startedAt: startedAt, endedAt: startedAt.addingTimeInterval(300),
        wasCompleted: true))
    await drain()

    // A staged task satisfies the gate on its own; `began(.focus)` promotes it, which
    // `beganFocusPromotesTheStagedTaskAndSeedsAttributionOnIt` covers.
    #expect(ctx.engine.isRunning)

    ctx.continuation.finish()
    await runTask.value
  }

  @Test func autoStartBreaksOnAutoStartFocusOffQueuesFocusAfterBreakEvenWithATaskTracked() async {
    let ctx = await makeContext()
    ctx.settings.autoStartBreaks = true
    ctx.settings.autoStartFocus = false
    ctx.activeTaskStore.track(
      makeTask(providerID: "local", nativeID: "abc", title: "Write plan"))
    let runTask = Task { await ctx.orchestrator.run() }

    let startedAt = Date(timeIntervalSinceReferenceDate: 0)
    ctx.continuation.yield(.began(phase: .shortBreak))
    ctx.continuation.yield(
      .ended(
        phase: .shortBreak, startedAt: startedAt, endedAt: startedAt.addingTimeInterval(300),
        wasCompleted: true))
    await drain()

    #expect(ctx.engine.state == .idle)
    #expect(ctx.engine.queuedPhase == .focus)

    ctx.continuation.finish()
    await runTask.value
  }

  @Test func autoStartFocusOnAutoStartBreaksOffQueuesTheBreakAfterFocusCompletes() async {
    let ctx = await makeContext()
    ctx.settings.autoStartFocus = true
    ctx.settings.autoStartBreaks = false
    let runTask = Task { await ctx.orchestrator.run() }

    let startedAt = Date(timeIntervalSinceReferenceDate: 0)
    let endedAt = startedAt.addingTimeInterval(1500)
    ctx.continuation.yield(.began(phase: .focus))
    ctx.continuation.yield(
      .ended(phase: .focus, startedAt: startedAt, endedAt: endedAt, wasCompleted: true))
    await drain()

    #expect(ctx.engine.state == .idle)
    #expect(ctx.engine.queuedPhase == .shortBreak)

    ctx.continuation.finish()
    await runTask.value
  }

  @Test func manualStopRecordsSessionButDoesNotNotifyOrAdvance() async {
    let ctx = await makeContext()
    let runTask = Task { await ctx.orchestrator.run() }

    let startedAt = Date(timeIntervalSinceReferenceDate: 0)
    let endedAt = startedAt.addingTimeInterval(300)
    ctx.continuation.yield(.began(phase: .focus))
    ctx.continuation.yield(
      .ended(phase: .focus, startedAt: startedAt, endedAt: endedAt, wasCompleted: false))
    await drain()

    #expect(ctx.store.sessions.count == 1)
    #expect(ctx.store.sessions.first?.wasCompleted == false)
    #expect(ctx.center.scheduledRequests.isEmpty)
    #expect(ctx.engine.queuedPhase == nil)
    #expect(ctx.engine.state == .idle)

    ctx.continuation.finish()
    await runTask.value
  }
}

/// Segment attribution (D1), the 30 s floor (D8), the durable draft upsert (D7), and staging
/// (design doc "stage the next focus") — split from ``PhaseOrchestratorTests`` to keep each
/// struct under the type-body-length limit.
@MainActor
struct PhaseOrchestratorSegmentTests {

  // MARK: - Segments (D1) and the 30 s floor (D8) of design doc 0010

  @Test func completedFocusRecordsOneSegmentForTheActiveTask() async {
    let ctx = await makeContext()
    let task = makeTask(providerID: "local", nativeID: "abc", title: "Write plan")
    ctx.activeTaskStore.track(task)
    let runTask = Task { await ctx.orchestrator.run() }

    let startedAt = Date(timeIntervalSinceReferenceDate: 0)
    let endedAt = startedAt.addingTimeInterval(1_500)
    ctx.continuation.yield(.began(phase: .focus))
    ctx.continuation.yield(
      .ended(phase: .focus, startedAt: startedAt, endedAt: endedAt, wasCompleted: true))
    await drain()

    #expect(ctx.store.sessions.first?.segments.count == 1)
    #expect(ctx.store.sessions.first?.segments.first?.taskRef == task.id)
    #expect(ctx.store.sessions.first?.segments.first?.taskTitle == task.title)
    #expect(ctx.store.sessions.first?.segments.first?.seconds == 1_500)

    ctx.continuation.finish()
    await runTask.value
  }

  @Test func breakPhaseRecordsNoSegments() async {
    let ctx = await makeContext()
    let task = makeTask(providerID: "local", nativeID: "abc", title: "Write plan")
    ctx.activeTaskStore.track(task)
    let runTask = Task { await ctx.orchestrator.run() }

    let startedAt = Date(timeIntervalSinceReferenceDate: 0)
    let endedAt = startedAt.addingTimeInterval(300)
    ctx.continuation.yield(.began(phase: .shortBreak))
    ctx.continuation.yield(
      .ended(phase: .shortBreak, startedAt: startedAt, endedAt: endedAt, wasCompleted: true))
    await drain()

    #expect(ctx.store.sessions.first?.segments.isEmpty == true)

    ctx.continuation.finish()
    await runTask.value
  }

  @Test func focusPhaseBelowFloorRecordsNothing() async {
    let ctx = await makeContext()
    let runTask = Task { await ctx.orchestrator.run() }

    let startedAt = Date(timeIntervalSinceReferenceDate: 0)
    let endedAt = startedAt.addingTimeInterval(20)  // under the 30 s floor
    ctx.continuation.yield(.began(phase: .focus))
    ctx.continuation.yield(
      .ended(phase: .focus, startedAt: startedAt, endedAt: endedAt, wasCompleted: false))
    await drain()

    #expect(ctx.store.sessions.isEmpty)

    ctx.continuation.finish()
    await runTask.value
  }

  @Test func focusPhaseAtFloorIsRecorded() async {
    let ctx = await makeContext()
    let runTask = Task { await ctx.orchestrator.run() }

    let startedAt = Date(timeIntervalSinceReferenceDate: 0)
    let endedAt = startedAt.addingTimeInterval(30)  // exactly at the floor
    ctx.continuation.yield(.began(phase: .focus))
    ctx.continuation.yield(
      .ended(phase: .focus, startedAt: startedAt, endedAt: endedAt, wasCompleted: false))
    await drain()

    #expect(ctx.store.sessions.count == 1)

    ctx.continuation.finish()
    await runTask.value
  }

  @Test func shortBreakBelowFloorIsStillRecorded() async {
    // The floor is focus-only (D8) — breaks are never gated by it.
    let ctx = await makeContext()
    let runTask = Task { await ctx.orchestrator.run() }

    let startedAt = Date(timeIntervalSinceReferenceDate: 0)
    let endedAt = startedAt.addingTimeInterval(5)
    ctx.continuation.yield(.began(phase: .shortBreak))
    ctx.continuation.yield(
      .ended(phase: .shortBreak, startedAt: startedAt, endedAt: endedAt, wasCompleted: false))
    await drain()

    #expect(ctx.store.sessions.count == 1)

    ctx.continuation.finish()
    await runTask.value
  }

  @Test func completedFocusAlwaysAboveFloorIsRecordedRegardlessOfActiveTask() async {
    let ctx = await makeContext()
    let runTask = Task { await ctx.orchestrator.run() }

    let startedAt = Date(timeIntervalSinceReferenceDate: 0)
    let endedAt = startedAt.addingTimeInterval(1_500)
    ctx.continuation.yield(.began(phase: .focus))
    ctx.continuation.yield(
      .ended(phase: .focus, startedAt: startedAt, endedAt: endedAt, wasCompleted: true))
    await drain()

    #expect(ctx.store.sessions.count == 1)
    #expect(ctx.store.sessions.first?.segments.count == 1)
    #expect(ctx.store.sessions.first?.segments.first?.taskRef == nil)

    ctx.continuation.finish()
    await runTask.value
  }

  // MARK: - Durable draft upsert (D7)

  @Test func midPhaseSliceCloseUpsertsDurableDraftOnceAboveFloor() async {
    var currentTime = Date(timeIntervalSinceReferenceDate: 1_000)
    let ctx = await makeContext(now: { currentTime })
    let taskA = makeTask(providerID: "local", nativeID: "a", title: "Task A")
    let taskB = makeTask(providerID: "local", nativeID: "b", title: "Task B")
    ctx.activeTaskStore.track(taskA)
    let runTask = Task { await ctx.orchestrator.run() }

    ctx.continuation.yield(.began(phase: .focus))
    await drain()
    currentTime = currentTime.addingTimeInterval(40)
    // Mirrors the AppComposition wiring: a task change reports the consumed focus time.
    ctx.attribution.taskChanged(to: taskB, consumedSeconds: 40)
    await drain()

    #expect(ctx.store.sessions.count == 1)
    #expect(ctx.store.sessions.first?.wasCompleted == false)
    #expect(ctx.store.sessions.first?.segments.count == 1)
    #expect(ctx.store.sessions.first?.segments.first?.taskRef == taskA.id)
    #expect(ctx.store.sessions.first?.segments.first?.seconds == 40.0)

    ctx.continuation.finish()
    await runTask.value
  }

  @Test func subFloorMidPhaseSliceCloseDoesNotDraft() async {
    let ctx = await makeContext()
    let taskA = makeTask(providerID: "local", nativeID: "a", title: "Task A")
    let taskB = makeTask(providerID: "local", nativeID: "b", title: "Task B")
    ctx.activeTaskStore.track(taskA)
    let runTask = Task { await ctx.orchestrator.run() }

    ctx.continuation.yield(.began(phase: .focus))
    await drain()
    ctx.attribution.taskChanged(to: taskB, consumedSeconds: 10)  // under the 30 s floor
    await drain()

    #expect(ctx.store.sessions.isEmpty)

    ctx.continuation.finish()
    await runTask.value
  }

  @Test func draftPersistsFromThePointItCrossesTheFloor() async {
    let ctx = await makeContext()
    let taskA = makeTask(providerID: "local", nativeID: "a", title: "Task A")
    let taskB = makeTask(providerID: "local", nativeID: "b", title: "Task B")
    let taskC = makeTask(providerID: "local", nativeID: "c", title: "Task C")
    ctx.activeTaskStore.track(taskA)
    let runTask = Task { await ctx.orchestrator.run() }

    ctx.continuation.yield(.began(phase: .focus))
    await drain()
    ctx.attribution.taskChanged(to: taskB, consumedSeconds: 10)  // still under the floor
    await drain()
    #expect(ctx.store.sessions.isEmpty)

    ctx.attribution.taskChanged(to: taskC, consumedSeconds: 40)  // crosses the floor (10 + 30)
    await drain()

    // The draft persists from this point on, including the earlier sub-floor slice.
    #expect(ctx.store.sessions.count == 1)
    #expect(ctx.store.sessions.first?.segments.map(\.seconds) == [10, 30])
    #expect(ctx.store.sessions.first?.segments.map { $0.taskRef } == [taskA.id, taskB.id])

    ctx.continuation.finish()
    await runTask.value
  }

  @Test func finalizeUpsertsOverAnExistingDraftRatherThanDuplicating() async {
    let ctx = await makeContext()
    let taskA = makeTask(providerID: "local", nativeID: "a", title: "Task A")
    let taskB = makeTask(providerID: "local", nativeID: "b", title: "Task B")
    ctx.activeTaskStore.track(taskA)
    let runTask = Task { await ctx.orchestrator.run() }

    ctx.continuation.yield(.began(phase: .focus))
    await drain()
    ctx.attribution.taskChanged(to: taskB, consumedSeconds: 40)  // upserts a draft
    await drain()
    #expect(ctx.store.sessions.count == 1)

    let startedAt = Date(timeIntervalSinceReferenceDate: 0)
    let endedAt = startedAt.addingTimeInterval(60)
    ctx.continuation.yield(
      .ended(phase: .focus, startedAt: startedAt, endedAt: endedAt, wasCompleted: true))
    await drain()

    // Same phase, one record — finalize replaced the draft rather than adding a second row.
    #expect(ctx.store.sessions.count == 1)
    #expect(ctx.store.sessions.first?.wasCompleted == true)
    #expect(ctx.store.sessions.first?.segments.map(\.seconds) == [40, 20])
    #expect(ctx.store.sessions.first?.segments.map { $0.taskRef } == [taskA.id, taskB.id])

    ctx.continuation.finish()
    await runTask.value
  }

  // MARK: - Staging (design doc "stage the next focus")

  @Test func beganFocusPromotesTheStagedTaskAndSeedsAttributionOnIt() async {
    let ctx = await makeContext()
    let staged = makeTask(providerID: "local", nativeID: "b", title: "Staged")
    ctx.activeTaskStore.stage(staged)
    let runTask = Task { await ctx.orchestrator.run() }

    let startedAt = Date(timeIntervalSinceReferenceDate: 0)
    let endedAt = startedAt.addingTimeInterval(1_500)
    ctx.continuation.yield(.began(phase: .focus))
    await drain()

    #expect(ctx.activeTaskStore.activeTask == staged)
    #expect(ctx.activeTaskStore.stagedTask == nil)

    ctx.continuation.yield(
      .ended(phase: .focus, startedAt: startedAt, endedAt: endedAt, wasCompleted: true))
    await drain()

    #expect(ctx.store.sessions.first?.segments.first?.taskRef == staged.id)

    ctx.continuation.finish()
    await runTask.value
  }

  @Test func beganShortBreakIgnoresAStagedTask() async {
    let ctx = await makeContext()
    let staged = makeTask(providerID: "local", nativeID: "b", title: "Staged")
    ctx.activeTaskStore.stage(staged)
    let runTask = Task { await ctx.orchestrator.run() }

    ctx.continuation.yield(.began(phase: .shortBreak))
    await drain()

    #expect(ctx.activeTaskStore.activeTask == nil)
    #expect(ctx.activeTaskStore.stagedTask == staged)

    ctx.continuation.finish()
    await runTask.value
  }

  @Test func skipFromPausedIntoFocusStaysPaused() {
    // The contract `applyStagedTask()` relies on: `skip()` can reach `.began(.focus)` from a
    // *paused* state, and must stay paused rather than silently resuming.
    let engine = SessionEngine()
    engine.start(phase: .shortBreak)
    engine.pause()
    engine.skip()
    guard case .paused(let phase, _) = engine.state else {
      Issue.record("Expected skip-from-paused to land paused, got \(engine.state)")
      return
    }
    #expect(phase == .focus)
  }
}
