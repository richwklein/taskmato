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
  private let attribution: FocusAttribution
  private let now: () -> Date

  /// Stable id for the phase currently in flight, assigned on `began` and reused by every
  /// mid-phase draft upsert and the final finalize, so they target the same row (D7).
  private var currentPhaseID: UUID?

  /// Segments closed so far in the current focus phase, accumulated as ``FocusAttribution``
  /// reports each slice close; the payload of the durable draft upsert.
  private var draftSegments: [FocusSegment] = []

  /// A focus phase whose consumed time falls below this floor is not recorded at all (D8 of
  /// design doc 0010) — it filters accidental starts and quick mis-taps. Breaks are unaffected.
  private static let focusFloorSeconds: TimeInterval = 30

  /// - Parameters:
  ///   - events: The phase-event stream to consume; production passes `engine.phaseEvents`.
  ///   - engine: The session engine, used to re-sync durations and advance/queue the next phase.
  ///   - store: Where completed sessions are recorded.
  ///   - settings: User preferences consulted for durations and auto-start behavior.
  ///   - selectionStore: Supplies the active task used to seed attribution on `began(.focus)`.
  ///   - notifications: Delivers the phase-end banner and sound.
  ///   - attribution: Resolves a focus phase's per-task slices (D4 of design doc 0010).
  ///   - now: Clock used to timestamp mid-phase draft upserts. Override in tests.
  init(
    events: AsyncStream<PhaseEvent>,
    engine: SessionEngine,
    store: SessionStore,
    settings: AppSettings,
    selectionStore: TaskSelectionStore,
    notifications: NotificationService,
    attribution: FocusAttribution,
    now: @escaping () -> Date = Date.init
  ) {
    self.events = events
    self.engine = engine
    self.store = store
    self.settings = settings
    self.selectionStore = selectionStore
    self.notifications = notifications
    self.attribution = attribution
    self.now = now
    attribution.onSliceClosed = { [weak self] segment in
      self?.upsertDraft(closing: segment)
    }
  }

  /// Consumes `events` for the lifetime of the stream, applying the cascade to each one.
  func run() async {
    for await event in events {
      switch event {
      case .began(let phase):
        began(phase: phase)
      case .ended(let phase, let startedAt, let endedAt, let wasCompleted):
        apply(phase: phase, startedAt: startedAt, endedAt: endedAt, wasCompleted: wasCompleted)
      }
    }
  }

  /// Assigns the phase's stable id, resets the draft, and — for focus only — promotes a staged
  /// task before seeding attribution with the task active at that moment.
  ///
  /// Promotion happens via `applyStagedTask()`, not `promoteStaged()`, so no resume fires here:
  /// `skip()` can reach `.began(.focus)` from a *paused* state, and skip-from-paused must stay
  /// paused (design doc "stage the next focus"). The `onActiveTaskChanged` promotion fires is a
  /// no-op regardless — `apply` calls `finish()` before `engine.start`/`enqueuePhase`, so
  /// `attribution.isLive` is false on every entry path.
  private func began(phase: SessionPhase) {
    currentPhaseID = UUID()
    draftSegments = []
    guard phase == .focus else { return }
    selectionStore.applyStagedTask()
    attribution.begin(task: selectionStore.activeTask)
  }

  /// Accumulates a newly closed slice and, once the phase's cumulative consumed time crosses
  /// the floor, upserts the durable draft (D7 and D8 of design doc 0010) so invested time
  /// survives even if the phase never reaches `.ended`.
  private func upsertDraft(closing segment: FocusSegment) {
    draftSegments.append(segment)
    let total = draftSegments.reduce(0) { $0 + $1.seconds }
    guard total >= Self.focusFloorSeconds, let id = currentPhaseID else { return }
    let end = now()
    let session = Session(
      id: id, phase: .focus, startedAt: end.addingTimeInterval(-total), endedAt: end,
      wasCompleted: false, segments: draftSegments)
    store.upsert(session)
  }

  /// Records the completed session, fires the phase notification, and advances the timer.
  private func apply(phase: SessionPhase, startedAt: Date, endedAt: Date, wasCompleted: Bool) {
    let duration = endedAt.timeIntervalSince(startedAt)
    let segments: [FocusSegment] =
      phase == .focus ? attribution.finish(consumedSeconds: duration) : []
    let belowFloor = phase == .focus && duration < Self.focusFloorSeconds
    if !belowFloor {
      let session = Session(
        id: currentPhaseID ?? UUID(), phase: phase, startedAt: startedAt,
        endedAt: endedAt, wasCompleted: wasCompleted, segments: segments)
      store.upsert(session)
    }
    currentPhaseID = nil
    draftSegments = []
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
