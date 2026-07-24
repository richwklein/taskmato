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

/// The start/pause · skip · stop control row shared by every timer surface.
///
/// All intents route through the injected ``TimerPresenter``; callers vary only the
/// ``TimerControlsSize`` and whether Start is disabled (typically when no task is
/// selected). The primary action renders tinted; skip and stop render bordered.
struct TimerControlsView: View {

  /// The presenter supplying timer state and receiving control intents.
  let presenter: TimerPresenter
  /// The button sizing preset for this surface.
  var size: TimerControlsSize = .regular
  /// Whether the Start button is disabled — typically when no task is selected.
  var startDisabled: Bool = false
  /// Tooltip shown on the Start button while it is disabled.
  var startDisabledHelp: String = ""

  var body: some View {
    HStack(spacing: size.spacing) {
      primaryButton

      ControlButton(
        label: AppLabels.Timer.skip.title,
        icon: AppLabels.Timer.skip.systemImage,
        diameter: size.secondaryDiameter
      ) { presenter.skip() }

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
    } else {
      ControlButton(
        label: AppLabels.Timer.start.title,
        icon: AppLabels.Timer.start.systemImage,
        isProminent: true,
        diameter: size.primaryDiameter
      ) { presenter.start() }
      .disabled(startDisabled)
      .help(startDisabled ? startDisabledHelp : "")
    }
  }
}
