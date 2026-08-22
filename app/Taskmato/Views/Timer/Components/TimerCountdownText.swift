//
//  TimerCountdownText.swift
//  Taskmato
//

import SwiftUI

/// The countdown digits alone, e.g. `"24:59"` — the top line ``TimerReadout`` stacks above the
/// phase name.
///
/// Extracted so ``FocusPresetReadout`` can wrap only this in its borderless `Menu` label and
/// render the phase name outside it: macOS collapses a stacked countdown-plus-phase-name `Menu`
/// label to a single text run, silently dropping the phase name — the reason "Ready to focus"
/// was unreachable on screen before this fix.
struct TimerCountdownText: View {

  /// The formatted time string, e.g. `"24:59"`.
  let label: String

  /// The countdown's base point size, scaled by Dynamic Type relative to `.largeTitle`.
  @ScaledMetric(relativeTo: .largeTitle) private var countdownSize: CGFloat = 36

  var body: some View {
    Text(label)
      .font(.system(size: countdownSize, weight: .light, design: .monospaced))
      .foregroundStyle(.primary)
  }
}
