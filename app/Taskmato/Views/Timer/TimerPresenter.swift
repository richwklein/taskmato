//
//  TimerPresenter.swift
//  Taskmato
//

import Foundation
import Observation

/// The single source of the timer's display values and user intents.
///
/// Wraps ``SessionEngine`` and ``AppSettings`` so every timer surface — the menu bar
/// countdown label, the popover, and the main-window timer — reads one `progress`,
/// `label`, and `phaseName`, and routes start/pause/resume/stop/skip through one place.
/// The latest durations are copied into the engine (via
/// ``SessionEngine/applyDurations(from:)``) on each `start` and `skip`, so a mid-session
/// duration change takes effect on the next phase.
@Observable
@MainActor
final class TimerPresenter {

  private let engine: SessionEngine
  private let settings: AppSettings

  /// - Parameters:
  ///   - engine: The session state machine driving the countdown.
  ///   - settings: The user-configured phase durations and cadence.
  init(engine: SessionEngine, settings: AppSettings) {
    self.engine = engine
    self.settings = settings
  }

  // MARK: - Display

  /// Fraction of the current phase remaining, from 1.0 (full) down to 0.0 (elapsed).
  var progress: Double {
    switch engine.state {
    case .idle:
      return 1.0
    case .running(_, _, let duration):
      guard duration > 0 else { return 1 }
      return engine.timeRemaining / duration
    case .paused(let phase, _):
      let duration = engineDuration(for: phase)
      guard duration > 0 else { return 1 }
      return engine.timeRemaining / duration
    }
  }

  /// The countdown formatted as `"MM:SS"` — the configured next-phase length while idle,
  /// otherwise the live time remaining.
  var label: String {
    let seconds: Int
    if case .idle = engine.state {
      seconds = Int(settingsDuration(for: nextStartPhase))
    } else {
      seconds = Int(engine.timeRemaining)
    }
    return String(format: "%02d:%02d", seconds / 60, seconds % 60)
  }

  /// The phase name — the idle "ready" label while idle, otherwise the active phase's name.
  var phaseName: String {
    switch engine.state {
    case .idle:
      return nextStartPhase.idleLabel
    case .running(let phase, _, _), .paused(let phase, _):
      return phase.displayName
    }
  }

  // MARK: - State

  /// `true` while a phase is actively counting down.
  var isRunning: Bool { engine.isRunning }

  /// `true` while a phase is paused mid-countdown.
  var isPaused: Bool {
    if case .paused = engine.state { return true }
    return false
  }

  /// `true` when no session is active.
  var isIdle: Bool { engine.state == .idle }

  /// `true` when there is a session to stop (running or paused).
  var canStop: Bool { engine.state != .idle }

  // MARK: - Intents

  /// Syncs the latest durations into the engine, then starts the queued (or focus) phase.
  func start() {
    engine.applyDurations(from: settings)
    engine.start(phase: nextStartPhase)
  }

  /// Suspends the current phase.
  func pause() { engine.pause() }

  /// Resumes a paused phase from where it left off.
  func resume() { engine.resume() }

  /// Stops the session and returns to idle.
  func stop() { engine.stop() }

  /// Syncs the latest durations into the engine, then skips to the next phase.
  func skip() {
    engine.applyDurations(from: settings)
    engine.skip(nextBreak: nextBreakPhase)
  }

  // MARK: - Helpers

  /// The phase Start begins from idle: a queued phase, or focus by default.
  private var nextStartPhase: SessionPhase {
    engine.queuedPhase ?? .focus
  }

  /// The break phase that follows the current focus phase on skip.
  private var nextBreakPhase: SessionPhase {
    engine.nextBreakPhase(longBreakAfter: settings.longBreakAfterSessions)
  }

  /// The engine's current duration for `phase` — used to scale paused progress.
  private func engineDuration(for phase: SessionPhase) -> TimeInterval {
    switch phase {
    case .focus: return engine.focusDuration
    case .shortBreak: return engine.shortBreakDuration
    case .longBreak: return engine.longBreakDuration
    }
  }

  /// The configured duration for `phase` — used for the idle countdown label.
  private func settingsDuration(for phase: SessionPhase) -> TimeInterval {
    switch phase {
    case .focus: return settings.focusDuration
    case .shortBreak: return settings.shortBreakDuration
    case .longBreak: return settings.longBreakDuration
    }
  }
}
