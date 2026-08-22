//
//  TimerReadout.swift
//  Taskmato
//

import SwiftUI

/// The countdown and phase name stacked vertically — the shared timer readout.
///
/// Used standalone by the slim menu-bar popover and centered inside
/// ``CircularTimerView`` on the window's Timer surface, so both render one countdown and
/// phase typography. The countdown line is ``TimerCountdownText``, shared with
/// ``FocusPresetReadout``'s menu label.
struct TimerReadout: View {

  /// The formatted time string, e.g. `"24:59"`.
  let label: String
  /// The phase name shown below the time, e.g. `"Focus"`.
  let phase: String

  var body: some View {
    VStack(spacing: .rowVertical) {
      TimerCountdownText(label: label)
      Text(phase)
        .font(.timerPhaseLabel)
        .foregroundStyle(.secondary)
    }
  }
}
