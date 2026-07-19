//
//  SessionStatsView.swift
//  Taskmato
//

import SwiftUI

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
