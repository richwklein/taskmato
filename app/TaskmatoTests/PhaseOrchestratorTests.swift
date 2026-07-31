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
  let selectionStore: TaskSelectionStore
  let center: FakeNotificationCenter
}

@MainActor
private func makeContext() async -> OrchestratorContext {
  let (stream, continuation) = AsyncStream.makeStream(of: PhaseEvent.self)
  let engine = SessionEngine()
  let store = SessionStore(repository: FakeSessionRepository())
  let settingsStore = SettingsStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
  let settings = AppSettings(store: settingsStore)
  let selectionStore = TaskSelectionStore(store: settingsStore)
  let center = FakeNotificationCenter(status: .authorized)
  let notifications = NotificationService(settings: settings, center: center)
  await notifications.refreshAuthStatus()
  let orchestrator = PhaseOrchestrator(
    events: stream, engine: engine, store: store, settings: settings,
    selectionStore: selectionStore, notifications: notifications)
  return OrchestratorContext(
    orchestrator: orchestrator, continuation: continuation, engine: engine, store: store,
    settings: settings, selectionStore: selectionStore, center: center)
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

  @Test func completedFocusRecordsSessionNotifiesAndQueuesNextPhase() async {
    let ctx = await makeContext()
    #expect(ctx.center.stubbedStatus == .authorized)
    let runTask = Task { await ctx.orchestrator.run() }

    let startedAt = Date(timeIntervalSinceReferenceDate: 0)
    let endedAt = startedAt.addingTimeInterval(1500)
    ctx.continuation.yield(
      .ended(phase: .focus, startedAt: startedAt, endedAt: endedAt, wasCompleted: true))
    await drain()

    #expect(ctx.store.sessions.count == 1)
    #expect(ctx.store.sessions.first?.phase == .focus)
    #expect(ctx.store.sessions.first?.wasCompleted == true)
    #expect(ctx.center.scheduledRequests.count == 1)
    // autoStartNextPhase defaults to false — the next phase is queued, not started.
    #expect(ctx.engine.queuedPhase == .shortBreak)
    #expect(ctx.engine.state == .idle)

    ctx.continuation.finish()
    await runTask.value
  }

  @Test func completedFocusAutoStartsNextPhaseWhenEnabled() async {
    let ctx = await makeContext()
    ctx.settings.autoStartNextPhase = true
    let runTask = Task { await ctx.orchestrator.run() }

    let startedAt = Date(timeIntervalSinceReferenceDate: 0)
    let endedAt = startedAt.addingTimeInterval(1500)
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

  @Test func manualStopRecordsSessionButDoesNotNotifyOrAdvance() async {
    let ctx = await makeContext()
    let runTask = Task { await ctx.orchestrator.run() }

    let startedAt = Date(timeIntervalSinceReferenceDate: 0)
    let endedAt = startedAt.addingTimeInterval(300)
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
