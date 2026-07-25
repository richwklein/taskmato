//
//  TimerRing.swift
//  Taskmato
//

import SwiftUI

/// A circular progress ring: a full track with an elapsed arc growing clockwise from 12 o'clock.
///
/// The single source of truth for the timer's ring appearance, sized by its ``diameter`` and
/// ``strokeWidth`` so both the large window ring and the compact strip glyph share one look.
struct TimerRing: View {

  /// Fraction of time remaining, from 1.0 (full) down to 0.0 (elapsed).
  let progress: Double
  /// Outer diameter of the ring.
  var diameter: CGFloat = 180
  /// Width of the track and arc stroke.
  var strokeWidth: CGFloat = 10

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
    }
    .frame(width: diameter, height: diameter)
  }
}
