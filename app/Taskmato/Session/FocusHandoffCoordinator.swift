//
//  FocusHandoffCoordinator.swift
//  Taskmato
//

import Foundation

/// Decides what a task-pick or handoff gesture does to the timer, gated on
/// ``AppSettings/startFocusOnTaskPick``.
///
/// Extracted from `AppComposition`'s handoff wiring so the start-vs-resume rules are testable
/// without the composition root. Routes through ``TimerPresenter`` so the D11 task gate is
/// applied in one place. Knows nothing about navigation — the caller handles that.
@MainActor
final class FocusHandoffCoordinator {

  private let presenter: TimerPresenter
  private let settings: AppSettings

  /// - Parameters:
  ///   - presenter: The presenter both methods delegate to for the actual start/resume and its
  ///     D11 task gate.
  ///   - settings: Consulted for ``AppSettings/startFocusOnTaskPick``.
  init(presenter: TimerPresenter, settings: AppSettings) {
    self.presenter = presenter
    self.settings = settings
  }

  /// Starts focus when a pick lands on an idle timer with focus next. `canSelectFocusPreset`
  /// excludes a running or paused phase and a queued break; `start()` applies the D11 task gate.
  func startFocusOnPick() {
    guard settings.startFocusOnTaskPick, presenter.canSelectFocusPreset else { return }
    presenter.start()
  }

  /// Resumes the remainder a handoff paused. Never starts from idle — `resume()` is inert unless
  /// a phase is actually paused, which is what keeps completing-with-a-staged-task from
  /// spontaneously opening a focus phase.
  /// - Returns: `true` when the toggle allowed the handoff to act, so the caller may also
  ///   navigate. `false` leaves the gesture inert, including its navigation — D9 of design doc
  ///   0010 couples returning to the Timer with the resume, so a declined handoff must not yank
  ///   the window.
  @discardableResult
  func resumeAfterHandoff() -> Bool {
    guard settings.startFocusOnTaskPick else { return false }
    presenter.resume()
    return true
  }
}
