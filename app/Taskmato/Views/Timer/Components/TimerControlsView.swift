//
//  TimerControlsView.swift
//  Taskmato
//

import SwiftUI

/// The size preset for ``TimerControlsView``, tuning the circular buttons and spacing.
enum TimerControlsSize {
  /// The compact preset used in the slim menu-bar popover.
  case compact
  /// The larger preset used on the window's Timer surface.
  case regular

  /// Diameter of the primary (start/pause/resume) button's icon frame.
  var primaryDiameter: CGFloat { self == .compact ? 34 : 44 }
  /// Diameter of the secondary (skip/stop) buttons' icon frames.
  var secondaryDiameter: CGFloat { self == .compact ? 28 : 36 }
  /// Horizontal spacing between the buttons.
  var spacing: CGFloat { self == .compact ? .groupGap : .sectionGap }
}

/// The transport control row — primary (Start/Pause/Resume) · Skip · Stop — whose
/// enablement derives from the session state in ``TimerPresenter``.
///
/// | Session state          | Primary | Skip | Stop |
/// |------------------------|---------|------|------|
/// | idle (nothing/focus queued) | Start   |  ✗   |  ✗   |
/// | idle (break queued)    | Start   |  ✓*  |  ✗   |
/// | running                | Pause   |  ✓   |  ✓   |
/// | paused                 | Resume  |  ✓   |  ✓   |
///
/// *Skip while idle cycles a queued break back to focus.
///
/// Both Start and Resume additionally require a task, since either would put focus on the clock;
/// the presenter's `primaryDisabled` decides. Skip stays available either way — it parks the focus
/// phase it opens rather than refusing. All intents route through the injected ``TimerPresenter``;
/// callers vary only the ``TimerControlsSize``. The primary action renders tinted; skip and stop
/// render bordered.
struct TimerControlsView: View {

  /// The presenter supplying timer state and receiving control intents.
  let presenter: TimerPresenter
  /// The button sizing preset for this surface.
  var size: TimerControlsSize = .regular
  /// Tooltip shown on the primary button while it is disabled for want of a task.
  var primaryDisabledHelp: String = ""

  var body: some View {
    HStack(spacing: size.spacing) {
      primaryButton

      ControlButton(
        label: AppLabels.Timer.skip.title,
        icon: AppLabels.Timer.skip.systemImage,
        diameter: size.secondaryDiameter
      ) { presenter.skip() }
      .disabled(!presenter.canSkip)

      ControlButton(
        label: AppLabels.Timer.stop.title,
        icon: AppLabels.Timer.stop.systemImage,
        diameter: size.secondaryDiameter
      ) { presenter.stop() }
      .disabled(!presenter.canStop)
    }
  }

  /// Start / Pause / Resume depending on engine state, rendered as the tinted primary.
  @ViewBuilder
  private var primaryButton: some View {
    if presenter.isRunning {
      ControlButton(
        label: AppLabels.Timer.pause.title,
        icon: AppLabels.Timer.pause.systemImage,
        isProminent: true,
        diameter: size.primaryDiameter
      ) { presenter.pause() }
    } else if presenter.isPaused {
      ControlButton(
        label: AppLabels.Timer.resume.title,
        icon: AppLabels.Timer.resume.systemImage,
        isProminent: true,
        diameter: size.primaryDiameter
      ) { presenter.resume() }
      .disabled(presenter.primaryDisabled)
      .help(presenter.primaryDisabled ? primaryDisabledHelp : "")
    } else {
      ControlButton(
        label: AppLabels.Timer.start.title,
        icon: AppLabels.Timer.start.systemImage,
        isProminent: true,
        diameter: size.primaryDiameter
      ) { presenter.start() }
      .disabled(presenter.primaryDisabled)
      .help(presenter.primaryDisabled ? primaryDisabledHelp : "")
    }
  }
}
