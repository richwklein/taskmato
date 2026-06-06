//
//  SessionEngine.swift
//  Taskmato
//

import Foundation
import Observation

/// The phase of an active or paused Pomodoro session.
enum SessionPhase: Equatable, Codable {
  /// A focus interval — the core work period.
  case focus
  /// A short recovery break, typically taken after each focus interval.
  case shortBreak
  /// A longer recovery break, typically taken after every fourth focus interval.
  case longBreak
}

extension SessionPhase {

  /// Display name used when a session is running or paused in this phase.
  var displayName: String {
    switch self {
    case .focus: return "Focus"
    case .shortBreak: return "Short Break"
    case .longBreak: return "Long Break"
    }
  }

  /// Display name used when the engine is idle and this phase is queued next.
  var idleLabel: String {
    switch self {
    case .focus: return "Ready to focus"
    case .shortBreak: return "Short Break"
    case .longBreak: return "Long Break"
    }
  }
}

/// The current state of the session engine's state machine.
enum SessionState: Equatable {
  /// No session is active. The engine is ready to start a new focus interval.
  case idle
  /// A session is actively counting down.
  /// - Parameters:
  ///   - phase: The current phase (focus or break).
  ///   - startedAt: The wall-clock time when this phase began (or was virtually backdated on resume).
  ///   - duration: The total length of this phase in seconds.
  case running(phase: SessionPhase, startedAt: Date, duration: TimeInterval)
  /// A session is suspended mid-phase.
  /// - Parameters:
  ///   - phase: The phase that was active when the session was paused.
  ///   - remaining: The number of seconds left when the session was paused.
  case paused(phase: SessionPhase, remaining: TimeInterval)
}

/// Manages the Pomodoro state machine and owns all timer logic.
///
/// `timeRemaining` is a stored observable property updated every second by an internal
/// timer while a session is running. Time is always derived from wall-clock timestamps,
/// so it stays accurate across sleep/wake cycles.
@Observable
final class SessionEngine {

  /// The current state of the session.
  private(set) var state: SessionState = .idle

  /// Seconds remaining in the current phase. Updated each second while running,
  /// frozen while paused, and reset to `focusDuration` when idle.
  private(set) var timeRemaining: TimeInterval

  /// Length of a focus interval in seconds. Updated from settings at each phase boundary.
  var focusDuration: TimeInterval

  /// Length of a short break in seconds. Updated from settings at each phase boundary.
  var shortBreakDuration: TimeInterval

  /// Length of a long break in seconds. Updated from settings at each phase boundary.
  var longBreakDuration: TimeInterval

  /// The next phase queued for manual start, set when a phase is skipped with auto-start disabled.
  /// Cleared whenever `start()` or `stop()` is called.
  private(set) var queuedPhase: SessionPhase?

  /// Number of focus phases that have completed naturally in the current session cycle.
  ///
  /// Incremented on each natural focus completion; reset to zero when a long break completes
  /// naturally. Manual stops and skips do not affect this counter.
  private(set) var completedFocusCount: Int = 0

  /// Called whenever a phase ends — either naturally (time reaches zero) or via manual stop.
  /// - Parameters:
  ///   - phase: The phase that ended.
  ///   - startedAt: Virtual start time, reflecting actual accumulated focus time.
  ///   - endedAt: The wall-clock time the phase ended.
  ///   - wasCompleted: `true` if time ran out naturally; `false` if the user stopped manually.
  var onPhaseEnded: ((SessionPhase, Date, Date, Bool) -> Void)?

  private let now: () -> Date
  private var tickTimer: Timer?

  /// - Parameters:
  ///   - focusDuration: Length of a focus interval in seconds.
  ///   - shortBreakDuration: Length of a short break in seconds.
  ///   - longBreakDuration: Length of a long break in seconds.
  ///   - now: Clock provider. Override in tests to control time.
  init(
    focusDuration: TimeInterval = 25 * 60,
    shortBreakDuration: TimeInterval = 5 * 60,
    longBreakDuration: TimeInterval = 15 * 60,
    now: @escaping () -> Date = Date.init
  ) {
    self.focusDuration = focusDuration
    self.shortBreakDuration = shortBreakDuration
    self.longBreakDuration = longBreakDuration
    self.now = now
    self.timeRemaining = focusDuration
  }

  /// `true` while a phase is actively counting down (not paused or idle).
  var isRunning: Bool {
    if case .running = state { return true }
    return false
  }

  /// Begins a new session in the specified phase. Defaults to `.focus`. Has no effect if a session is already active or paused.
  func start(phase: SessionPhase = .focus) {
    guard case .idle = state else { return }
    queuedPhase = nil
    let dur = duration(for: phase)
    timeRemaining = dur
    state = .running(phase: phase, startedAt: now(), duration: dur)
    startTicking()
  }

  /// Suspends the current phase, capturing the remaining time. Has no effect when idle or already paused.
  func pause() {
    guard case .running(let phase, _, _) = state else { return }
    refreshTimeRemaining()
    guard case .running = state else { return }  // completion may have fired during refresh
    stopTicking()
    state = .paused(phase: phase, remaining: timeRemaining)
  }

  /// Resumes a paused session from where it left off. Has no effect when running or idle.
  func resume() {
    guard case .paused(let phase, let remaining) = state else { return }
    let duration = self.duration(for: phase)
    timeRemaining = remaining
    state = .running(
      phase: phase,
      startedAt: now().addingTimeInterval(-(duration - remaining)),
      duration: duration
    )
    startTicking()
  }

  /// Stops the session, records a partial session if one was in progress, and returns to idle.
  func stop() {
    let endedAt = now()
    switch state {
    case .running(let phase, let startedAt, _):
      stopTicking()
      refreshTimeRemaining()
      onPhaseEnded?(phase, startedAt, endedAt, false)
    case .paused(let phase, let remaining):
      let elapsed = duration(for: phase) - remaining
      let startedAt = endedAt.addingTimeInterval(-elapsed)
      onPhaseEnded?(phase, startedAt, endedAt, false)
    case .idle:
      return
    }
    state = .idle
    timeRemaining = focusDuration
    queuedPhase = nil
  }

  /// Advances to the next phase, preserving the current running state.
  ///
  /// - Running: the next phase starts immediately.
  /// - Paused: the next phase begins paused at its full duration.
  /// - Idle: queues focus as the next phase (cycling a pending break back to focus).
  /// - Parameter nextBreak: The break phase to use when skipping from a focus phase. Defaults to `.shortBreak`.
  func skip(nextBreak: SessionPhase = .shortBreak) {
    let currentPhase: SessionPhase
    let wasRunning: Bool
    switch state {
    case .running(let phase, _, _):
      currentPhase = phase
      wasRunning = true
    case .paused(let phase, _):
      currentPhase = phase
      wasRunning = false
    case .idle:
      queuedPhase = .focus
      return
    }
    stopTicking()
    let next: SessionPhase = (currentPhase == .focus) ? nextBreak : .focus
    let dur = duration(for: next)
    timeRemaining = dur
    queuedPhase = nil
    if wasRunning {
      state = .running(phase: next, startedAt: now(), duration: dur)
      startTicking()
    } else {
      state = .paused(phase: next, remaining: dur)
    }
  }

  /// Returns the break phase that should follow the next completed focus session.
  ///
  /// Returns `.longBreak` when `completedFocusCount` is a non-zero multiple of `longBreakAfter`;
  /// otherwise returns `.shortBreak`.
  /// - Parameter longBreakAfter: Number of completed focus sessions before a long break is due.
  func nextBreakPhase(longBreakAfter: Int) -> SessionPhase {
    guard longBreakAfter > 0, completedFocusCount > 0,
      completedFocusCount % longBreakAfter == 0
    else { return .shortBreak }
    return .longBreak
  }

  /// Queues a phase to start next without beginning it. Only has effect when idle.
  func enqueuePhase(_ phase: SessionPhase) {
    guard case .idle = state else { return }
    queuedPhase = phase
  }

  // Recomputes timeRemaining from the stored start timestamp.
  // Called on each timer tick and immediately before pausing.
  // Detects natural phase completion when remaining time reaches zero.
  private func refreshTimeRemaining() {
    guard case .running(let phase, let startedAt, let duration) = state else { return }
    let remaining = max(0, duration - now().timeIntervalSince(startedAt))
    timeRemaining = remaining
    if remaining <= 0 {
      stopTicking()
      state = .idle
      timeRemaining = focusDuration
      switch phase {
      case .focus: completedFocusCount += 1
      case .longBreak: completedFocusCount = 0
      case .shortBreak: break
      }
      onPhaseEnded?(phase, startedAt, startedAt.addingTimeInterval(duration), true)
    }
  }

  private func startTicking() {
    stopTicking()
    let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
      self?.refreshTimeRemaining()
    }
    // .common mode keeps the timer firing while menus and popovers are open.
    RunLoop.main.add(timer, forMode: .common)
    tickTimer = timer
  }

  private func stopTicking() {
    tickTimer?.invalidate()
    tickTimer = nil
  }

  private func duration(for phase: SessionPhase) -> TimeInterval {
    switch phase {
    case .focus: return focusDuration
    case .shortBreak: return shortBreakDuration
    case .longBreak: return longBreakDuration
    }
  }
}
