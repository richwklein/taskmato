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
///
/// Focus time is always credited to a task, so this is also where that invariant is enforced:
/// no intent here puts a focus phase on the clock while nothing is tracked. The engine stays
/// task-agnostic (D4 of design doc 0010) — the policy lives here, and every surface reads it
/// through ``primaryDisabled`` and ``canSkip`` rather than recomputing it.
@Observable
@MainActor
final class TimerPresenter {

  private let engine: SessionEngine
  private let settings: AppSettings
  private let activeTaskStore: ActiveTaskStore

  /// - Parameters:
  ///   - engine: The session state machine driving the countdown.
  ///   - settings: The user-configured phase durations and cadence.
  ///   - activeTaskStore: Supplies the tracked and staged tasks the focus gates consult.
  init(engine: SessionEngine, settings: AppSettings, activeTaskStore: ActiveTaskStore) {
    self.engine = engine
    self.settings = settings
    self.activeTaskStore = activeTaskStore
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

  /// Phase (plus paused) and coarse remaining time announced to VoiceOver, e.g. "Focus, 24 minutes remaining".
  ///
  /// Whole-minute granularity avoids per-second VoiceOver re-announcement while focus is parked on the ring;
  /// the final 10 seconds count down by seconds as an intentional finish cue. The visible `label` stays precise.
  var accessibilityValue: String {
    if case .idle = engine.state {
      let seconds = Int(settingsDuration(for: nextStartPhase))
      return "\(phaseName), \(Self.spokenRemaining(seconds, includeRemaining: false))"
    }
    let seconds = Int(engine.timeRemaining)
    let phase = isPaused ? "\(phaseName), paused" : phaseName
    return "\(phase), \(Self.spokenRemaining(seconds, includeRemaining: true))"
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

  /// `true` when Skip has an effect: an active phase to advance, or a queued break to
  /// cycle back to focus while idle.
  ///
  /// Never gated on having a task: leaving a break early is always allowed, and ``skip()`` parks
  /// the focus phase it opens rather than refusing the gesture.
  var canSkip: Bool {
    if engine.state != .idle { return true }
    guard let queued = engine.queuedPhase else { return false }
    return queued != .focus  // a break is queued; idle-skip cycles it to focus
  }

  /// `true` when the primary transport control must stay disabled because it would put focus on
  /// the clock with nothing to credit the time to — the single gate behind Start *and* Resume.
  ///
  /// Start accepts a staged task, since `PhaseOrchestrator.began(.focus)` promotes it as the phase
  /// opens. Resume does not: it yields no `.began`, so a staged task would never be promoted and
  /// the remainder really would run untracked. Pause is never gated.
  var primaryDisabled: Bool {
    switch engine.state {
    case .running:
      return false
    case .paused(let phase, _):
      return phase == .focus && activeTaskStore.activeTask == nil
    case .idle:
      return nextStartPhase == .focus && !hasTaskForFocus
    }
  }

  /// `true` when a focus phase opened now would have a task to credit — one tracked, or one
  /// staged for promotion at the phase boundary.
  private var hasTaskForFocus: Bool {
    activeTaskStore.activeTask != nil || activeTaskStore.stagedTask != nil
  }

  // MARK: - Focus presets

  /// `true` while idle with focus as the next phase to start — the only state in which choosing a
  /// focus length changes what the countdown is showing.
  ///
  /// Narrower than ``isIdle``: the engine also returns to idle *between* phases with a break
  /// queued, and there the readout is counting down that break, not focus (issue #580).
  var canSelectFocusPreset: Bool { isIdle && nextStartPhase == .focus }

  /// Focus-length presets to offer, ascending, in minutes.
  ///
  /// Mirrors `settings.focusPresets`, but prepends the current `focusMinutes` when it holds a
  /// custom value outside that list (design doc 0009, D6) so a quick-select surface always has
  /// something to highlight as selected.
  var focusPresets: [Int] {
    let presets = settings.focusPresets
    guard presets.contains(settings.focusMinutes) else {
      return ([settings.focusMinutes] + presets).sorted()
    }
    return presets
  }

  /// Whether to surface the quick-select picker — only while focus is the next phase to start and
  /// more than one preset exists, since a single focus length offers nothing to choose between
  /// (design doc 0009).
  var showsFocusPresetPicker: Bool { canSelectFocusPreset && focusPresets.count > 1 }

  /// The currently-selected focus length, in minutes — always `settings.focusMinutes`.
  var selectedFocusMinutes: Int { settings.focusMinutes }

  /// Selects a focus preset for the next session. A no-op while running, paused, or with a break
  /// queued, since a mid-session duration change only takes effect at the next phase boundary
  /// anyway.
  func selectFocusPreset(_ minutes: Int) {
    guard canSelectFocusPreset else { return }
    settings.focusMinutes = minutes
  }

  // MARK: - Intents

  /// Syncs the latest durations into the engine, then starts the queued (or focus) phase.
  /// A no-op when ``primaryDisabled`` — starting focus with nothing to credit.
  func start() {
    guard !primaryDisabled else { return }
    engine.applyDurations(from: settings)
    engine.start(phase: nextStartPhase)
  }

  /// Suspends the current phase.
  func pause() { engine.pause() }

  /// Resumes a paused phase from where it left off. A no-op when ``primaryDisabled`` — resuming
  /// focus with nothing to credit.
  func resume() {
    guard !primaryDisabled else { return }
    engine.resume()
    activeTaskStore.clearPendingContinuation()
  }

  /// Stops the session and returns to idle.
  func stop() {
    engine.stop()
    activeTaskStore.clearPendingContinuation()
  }

  /// Syncs the latest durations into the engine, then skips to the next phase.
  ///
  /// Leaving a break early is always allowed, but the focus phase it opens is parked when there is
  /// nothing to credit — the break still advances, the remainder just waits for a task. A staged
  /// task counts: `began(.focus)` promotes it when the orchestrator drains the event this yields,
  /// which happens after this returns.
  func skip() {
    guard canSkip else { return }
    engine.applyDurations(from: settings)
    engine.skip(nextBreak: nextBreakPhase)
    guard !hasTaskForFocus, case .running(.focus, _, _) = engine.state else { return }
    engine.pause()
  }

  /// Pauses a running focus phase left with no tracked task, so no focus time accrues
  /// unattributed. Mirrors what ``ActiveTaskReconciler`` does when a task vanishes from its
  /// provider; call it after any path that detaches the tracked task without pausing first.
  /// A no-op during a break, while idle, or while a task is still tracked.
  func pauseUntrackedFocus() {
    guard activeTaskStore.activeTask == nil, case .running(.focus, _, _) = engine.state else {
      return
    }
    engine.pause()
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

  /// Formats a remaining-seconds count for VoiceOver: whole minutes (floored) above a minute,
  /// a vague phrase in the sub-minute band, and per-second detail in the final 10 seconds.
  private static func spokenRemaining(_ seconds: Int, includeRemaining: Bool) -> String {
    let suffix = includeRemaining ? " remaining" : ""
    if seconds >= 60 {
      let minutes = seconds / 60
      let unit = minutes == 1 ? "minute" : "minutes"
      return "\(minutes) \(unit)\(suffix)"
    }
    if seconds > 10 {
      return "less than a minute\(suffix)"
    }
    let unit = seconds == 1 ? "second" : "seconds"
    return "\(seconds) \(unit)\(suffix)"
  }
}
