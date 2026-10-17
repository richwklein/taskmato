//
//  PhaseOrchestratorNotificationTests.swift
//  TaskmatoTests
//

import Foundation
import Testing
import UserNotifications

@testable import Taskmato

// MARK: - Fakes

/// A controllable stand-in for UNUserNotificationCenter (spy pattern from NotificationServiceTests).
private final class FakeNotificationCenter: NotificationCenterAPI {
  private(set) var scheduledRequests: [UNNotificationRequest] = []

  func authorizationStatus() async -> UNAuthorizationStatus { .authorized }

  func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool { true }

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
  let settings: AppSettings
  let center: FakeNotificationCenter

  var bannerBody: String? { center.scheduledRequests.first?.content.body }
}

@MainActor
private func makeContext() async -> OrchestratorContext {
  let (stream, continuation) = AsyncStream.makeStream(of: PhaseEvent.self)
  let engine = SessionEngine()
  let settingsStore = SettingsStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
  let settings = AppSettings(store: settingsStore)
  let center = FakeNotificationCenter()
  let notifications = NotificationService(settings: settings, center: center)
  await notifications.refreshAuthStatus()
  let orchestrator = PhaseOrchestrator(
    events: stream, engine: engine, store: SessionStore(repository: FakeSessionRepository()),
    settings: settings, activeTaskStore: ActiveTaskStore(store: settingsStore),
    notifications: notifications, attribution: FocusAttribution())
  return OrchestratorContext(
    orchestrator: orchestrator, continuation: continuation, engine: engine, settings: settings,
    center: center)
}

/// Yields the main-actor executor repeatedly, giving a concurrently running `Task` a chance to
/// drain buffered `AsyncStream` values before assertions run.
@MainActor
private func drain() async {
  for _ in 0..<20 { await Task.yield() }
}

// MARK: - Tests

/// Phase-end banner copy chosen by ``PhaseOrchestrator`` — which next phase and outcome it reports
/// — split from ``PhaseOrchestratorTests`` to keep each file under the file-length limit.
@MainActor
struct PhaseOrchestratorNotificationTests {

  @Test func completedBreakWithNoTaskAwaitsATaskEvenWithAutoStartFocusOff() async {
    let ctx = await makeContext()
    let runTask = Task { await ctx.orchestrator.run() }

    let startedAt = Date(timeIntervalSinceReferenceDate: 0)
    ctx.continuation.yield(.began(phase: .shortBreak))
    ctx.continuation.yield(
      .ended(
        phase: .shortBreak, startedAt: startedAt, endedAt: startedAt.addingTimeInterval(300),
        wasCompleted: true))
    await drain()

    #expect(ctx.engine.queuedPhase == .focus)
    #expect(ctx.bannerBody == AppLabels.PhaseEnd.body(next: .focus, outcome: .awaitingTask))

    ctx.continuation.finish()
    await runTask.value
  }

  @Test func completedFocusAfterAStartLandsFirstDoesNotClaimTheBreakStarted() async {
    let ctx = await makeContext()
    ctx.settings.autoStartBreaks = true
    ctx.engine.start(phase: .focus)
    let runTask = Task { await ctx.orchestrator.run() }

    let startedAt = Date(timeIntervalSinceReferenceDate: 0)
    ctx.continuation.yield(.began(phase: .focus))
    ctx.continuation.yield(
      .ended(
        phase: .focus, startedAt: startedAt, endedAt: startedAt.addingTimeInterval(1500),
        wasCompleted: true))
    await drain()

    guard case .running(let phase, _, _) = ctx.engine.state else {
      Issue.record("Expected the engine to still be running the focus phase that landed first")
      ctx.continuation.finish()
      return
    }
    #expect(phase == .focus)
    #expect(ctx.bannerBody == AppLabels.PhaseEnd.body(next: .shortBreak, outcome: .queued))

    ctx.continuation.finish()
    await runTask.value
  }

  @Test(arguments: [(true, PhaseEndOutcome.started), (false, .queued)])
  func completedFocusAtTheLongBreakThresholdHandsOffToALongBreak(
    autoStartBreaks: Bool, outcome: PhaseEndOutcome
  ) async {
    let ctx = await makeContext()
    ctx.settings.autoStartBreaks = autoStartBreaks
    ctx.settings.longBreakAfterSessions = 1
    ctx.engine.focusDuration = 0
    ctx.engine.start(phase: .focus)
    ctx.engine.pause()
    #expect(ctx.engine.completedFocusCount == 1)
    let runTask = Task { await ctx.orchestrator.run() }

    let startedAt = Date(timeIntervalSinceReferenceDate: 0)
    ctx.continuation.yield(.began(phase: .focus))
    ctx.continuation.yield(
      .ended(
        phase: .focus, startedAt: startedAt, endedAt: startedAt.addingTimeInterval(1500),
        wasCompleted: true))
    await drain()

    if autoStartBreaks {
      guard case .running(let phase, _, _) = ctx.engine.state else {
        Issue.record("Expected the engine to have auto-started the long break")
        ctx.continuation.finish()
        return
      }
      #expect(phase == .longBreak)
    } else {
      #expect(ctx.engine.queuedPhase == .longBreak)
    }
    #expect(ctx.engine.isRunning == autoStartBreaks)
    #expect(ctx.bannerBody == AppLabels.PhaseEnd.body(next: .longBreak, outcome: outcome))

    ctx.continuation.finish()
    await runTask.value
  }
}
