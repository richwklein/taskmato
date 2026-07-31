//
//  PhaseOrchestrator.swift
//  Taskmato
//

import Foundation

/// Drives the phase-end side-effect cascade from a stream of ``PhaseEvent`` values.
///
/// Consumes ``SessionEngine/phaseEvents``: records the completed session, fires the phase
/// notification, re-syncs engine durations from settings, and advances or queues the next
/// phase. Isolating this cascade behind an injected stream makes it testable without a real
/// clock or the live app services.
@MainActor
final class PhaseOrchestrator {

  private let events: AsyncStream<PhaseEvent>
  private let engine: SessionEngine
  private let store: SessionStore
  private let settings: AppSettings
  private let selectionStore: TaskSelectionStore
  private let notifications: NotificationService

  /// - Parameters:
  ///   - events: The phase-event stream to consume; production passes `engine.phaseEvents`.
  ///   - engine: The session engine, used to re-sync durations and advance/queue the next phase.
  ///   - store: Where completed sessions are recorded.
  ///   - settings: User preferences consulted for durations and auto-start behavior.
  ///   - selectionStore: Supplies the active task recorded alongside each session.
  ///   - notifications: Delivers the phase-end banner and sound.
  init(
    events: AsyncStream<PhaseEvent>,
    engine: SessionEngine,
    store: SessionStore,
    settings: AppSettings,
    selectionStore: TaskSelectionStore,
    notifications: NotificationService
  ) {
    self.events = events
    self.engine = engine
    self.store = store
    self.settings = settings
    self.selectionStore = selectionStore
    self.notifications = notifications
  }

  /// Consumes `events` for the lifetime of the stream, applying the cascade to each one.
  func run() async {
    for await case .ended(let phase, let startedAt, let endedAt, let wasCompleted) in events {
      apply(phase: phase, startedAt: startedAt, endedAt: endedAt, wasCompleted: wasCompleted)
    }
  }

  /// Records the completed session, fires the phase notification, and advances the timer.
  private func apply(phase: SessionPhase, startedAt: Date, endedAt: Date, wasCompleted: Bool) {
    let session = Session(
      id: UUID(), phase: phase, startedAt: startedAt,
      endedAt: endedAt, wasCompleted: wasCompleted,
      taskRef: selectionStore.activeTask?.id,
      taskTitle: selectionStore.activeTask?.title
    )
    store.append(session)
    guard wasCompleted else { return }
    notifications.send(phase: phase)
    engine.applyDurations(from: settings)
    let next: SessionPhase
    switch phase {
    case .focus:
      next = engine.nextBreakPhase(longBreakAfter: settings.longBreakAfterSessions)
    case .shortBreak, .longBreak:
      next = .focus
    }
    if settings.autoStartNextPhase {
      engine.start(phase: next)
    } else {
      engine.enqueuePhase(next)
    }
  }
}
