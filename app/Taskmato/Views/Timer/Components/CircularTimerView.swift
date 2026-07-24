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

  private let ringDiameter: CGFloat = 180
  private let strokeWidth: CGFloat = 10

  var body: some View {
    ZStack {
      Circle()
        .stroke(Color.timerRingTrack, lineWidth: strokeWidth)

      // Elapsed arc grows clockwise from 12 o'clock as time passes.
      Circle()
        .trim(from: 0, to: 1 - progress)
        .stroke(
          Color.accentColor,
          style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
        )
        .rotationEffect(.degrees(-90))
        .animation(.linear(duration: 1), value: progress)

      TimerReadout(label: label, phase: phase)
    }
    .frame(width: ringDiameter, height: ringDiameter)
  }
}
