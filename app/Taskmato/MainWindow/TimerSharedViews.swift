//
//  TimerSharedViews.swift
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
        .stroke(Color.secondary.opacity(0.2), lineWidth: strokeWidth)

      // Elapsed arc grows clockwise from 12 o'clock as time passes.
      Circle()
        .trim(from: 0, to: 1 - progress)
        .stroke(
          Color.accentColor,
          style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
        )
        .rotationEffect(.degrees(-90))
        .animation(.linear(duration: 1), value: progress)

      VStack(spacing: 4) {
        Text(label)
          .font(.system(size: 36, weight: .light, design: .monospaced))
          .foregroundStyle(.primary)
        Text(phase)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
    }
    .frame(width: ringDiameter, height: ringDiameter)
  }
}

/// A compact icon-only button used in the timer controls row.
struct ControlButton: View {

  /// The accessibility label and tooltip for this button.
  let label: String
  /// SF Symbol name for the button icon.
  let icon: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Label(label, systemImage: icon)
        .labelStyle(.iconOnly)
        .frame(width: 32, height: 32)
    }
    .buttonStyle(.bordered)
    .help(label)
  }
}

/// A compact summary row showing today's focus session count and total focused time.
struct SessionStatsView: View {

  /// Number of completed focus sessions today.
  let count: Int
  /// Total minutes of completed focus time today.
  let minutes: Int

  var body: some View {
    HStack {
      Label(sessionLabel, systemImage: "timer")
      Spacer()
      Label(minuteLabel, systemImage: "clock")
    }
    .font(.caption)
    .foregroundStyle(.secondary)
  }

  private var sessionLabel: String {
    count == 1 ? "1 session today" : "\(count) sessions today"
  }

  private var minuteLabel: String {
    "\(minutes) min focused"
  }
}
