//
//  SessionStatsView.swift
//  Taskmato
//

import SwiftUI

/// A compact summary row showing today's focus session count, focused time, and current streak.
struct SessionStatsView: View {

  /// Number of completed focus sessions today.
  let count: Int
  /// Total minutes of completed focus time today.
  let minutes: Int
  /// Current consecutive-day focus streak; `0` hides the streak indicator.
  var streak: Int = 0

  var body: some View {
    HStack {
      Text(sessionLabel)
      Spacer()
      Text(minuteLabel)
    }
    .font(.caption)
    .foregroundStyle(.secondary)
  }

  private var sessionLabel: String {
    count == 1 ? "1 session today" : "\(count) sessions today"
  }

  private var minuteLabel: String {
    streak > 0 ? "\(minutes) min · 🔥\(streak)" : "\(minutes) min focused"
  }
}
