//
//  TimerControlsView.swift
//  Taskmato
//

import SwiftUI

/// The start/pause · skip · stop control row shared by every timer surface.
///
/// All intents route through the injected ``TimerPresenter``; the only surface-specific
/// input is whether Start is disabled (typically when no task is selected).
struct TimerControlsView: View {

  /// The presenter supplying timer state and receiving control intents.
  let presenter: TimerPresenter
  /// Whether the Start button is disabled — typically when no task is selected.
  var startDisabled: Bool = false
  /// Tooltip shown on the Start button while it is disabled.
  var startDisabledHelp: String = ""

  var body: some View {
    HStack(spacing: .groupGap) {
      if presenter.isRunning {
        ControlButton(
          label: AppLabels.Timer.pause.title,
          icon: AppLabels.Timer.pause.systemImage
        ) { presenter.pause() }
      } else if presenter.isPaused {
        ControlButton(
          label: AppLabels.Timer.resume.title,
          icon: AppLabels.Timer.resume.systemImage
        ) { presenter.resume() }
      } else {
        ControlButton(
          label: AppLabels.Timer.start.title,
          icon: AppLabels.Timer.start.systemImage
        ) { presenter.start() }
        .disabled(startDisabled)
        .help(startDisabled ? startDisabledHelp : "")
      }

      ControlButton(
        label: AppLabels.Timer.skip.title,
        icon: AppLabels.Timer.skip.systemImage
      ) { presenter.skip() }

      ControlButton(
        label: AppLabels.Timer.stop.title,
        icon: AppLabels.Timer.stop.systemImage
      ) { presenter.stop() }
      .disabled(!presenter.canStop)
    }
  }
}
