//
//  CircularTimerView.swift
//  Taskmato
//

import SwiftUI

/// A circular progress ring with a countdown label and phase name centered inside.
struct CircularTimerView: View {

  /// Fraction of time remaining, from 1.0 (full) down to 0.0 (elapsed).
  let progress: Double
  /// The formatted time string displayed in the center, e.g. `"24:59"`.
  let label: String
  /// The phase name displayed below the time, e.g. `"Focus"`.
  let phase: String
  /// The VoiceOver value announced for the ring, e.g. `"Focus, 24 minutes remaining"`.
  let accessibilityValue: String

  private let ringDiameter: CGFloat = 180
  private let strokeWidth: CGFloat = 10

  var body: some View {
    ZStack {
      TimerRing(progress: progress, diameter: ringDiameter, strokeWidth: strokeWidth)
      TimerReadout(label: label, phase: phase)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(AppLabels.Accessibility.timer)
    .accessibilityValue(accessibilityValue)
    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
  }
}
