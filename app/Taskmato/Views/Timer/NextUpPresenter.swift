//
//  NextUpPresenter.swift
//  Taskmato
//

import Foundation
import Observation

/// Supplies the staged "next focus" readout's content (design doc "stage the next focus", D-d).
///
/// Depends on ``TimerPresenter`` — never the reverse — so `TimerPresenter` stays task-agnostic
/// (design doc 0010, D4) for the menu-bar popover, which has no staging concept. Constructed once
/// in `AppComposition` and handed only to the Timer tab's ring and ``ActiveTaskView`` at
/// `.detail`, so the popover structurally cannot show next-up.
@Observable
@MainActor
final class NextUpPresenter {

  private let presenter: TimerPresenter
  private let selectionStore: TaskSelectionStore
  private let settings: AppSettings

  /// - Parameters:
  ///   - presenter: Supplies the timer's phase state; the single source of "focus is next"
  ///     rather than re-deriving it here.
  ///   - selectionStore: Supplies the staged task.
  ///   - settings: Supplies the live focus length.
  init(presenter: TimerPresenter, selectionStore: TaskSelectionStore, settings: AppSettings) {
    self.presenter = presenter
    self.selectionStore = selectionStore
    self.settings = settings
  }

  /// `true` while a task is staged *and* the countdown is not already showing that length.
  ///
  /// Staging survives `stop()` (D-e), so a task staged during a break can outlive the session
  /// and leave the engine idle with focus next — where the ring already reads `45:00` and a
  /// "Next focus: 45 min" beneath it would only restate it. Design doc 0009 resolved that state
  /// as "no line", so it collapses. The staged *task* still shows in ``ActiveTaskView``, since
  /// which task runs next is not restated anywhere.
  var showsNextUp: Bool { selectionStore.stagedTask != nil && !presenter.canSelectFocusPreset }

  /// The task staged for the next focus phase, or `nil` when nothing is staged.
  var stagedTask: TaskItem? { selectionStore.stagedTask }

  /// The length the next focus phase will run, in minutes — always `settings.focusMinutes`, read
  /// live. There is no separate staged-length state (D-b): a persisted slot could diverge from
  /// what the engine actually applies, since `AppSettings.focusPresets`'s setter can re-snap
  /// `focusMinutes` behind a cached value's back.
  var nextFocusMinutes: Int { settings.focusMinutes }
}
