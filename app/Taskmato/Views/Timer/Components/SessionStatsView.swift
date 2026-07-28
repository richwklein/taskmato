//
//  SessionStatsView.swift
//  Taskmato
//

import SwiftUI

/// How ``SessionStatsView`` arranges its figures.
enum SessionStatsLayout {
  /// Timer destination: count leading, minutes trailing, spread across the row.
  case spread
  /// Popover bottom bar: one dot-separated run.
  case inline
}

/// A compact summary row showing today's focus session count, focused time, and current streak.
struct SessionStatsView: View {

  /// Number of completed focus sessions today.
  let count: Int
  /// Total minutes of completed focus time today.
  let minutes: Int
  /// Current consecutive-day focus streak; `0` hides the streak indicator.
  var streak: Int = 0
  /// How the summary figures are arranged.
  var layout: SessionStatsLayout = .spread
  /// Invoked when the summary is clicked; `nil` renders it as non-interactive text.
  var onSelect: (() -> Void)?

  var body: some View {
    if let onSelect {
      Button(action: onSelect) { content }
        .buttonStyle(.plain)
        .contentShape(.rect)
        .help(AppLabels.Tab.stats.title)
    } else {
      content
    }
  }

  @ViewBuilder
  private var content: some View {
    switch layout {
    case .spread:
      HStack {
        Text(sessionLabel)
        Spacer()
        Text(minuteLabel)
      }
      .font(.caption)
      .foregroundStyle(.secondary)
    case .inline:
      Text(inlineText)
        .font(.statLabel)
        .foregroundStyle(.secondary)
    }
  }

  private var sessionLabel: String {
    count == 1 ? "1 session today" : "\(count) sessions today"
  }

  private var minuteLabel: String {
    streak > 0 ? "\(minutes) min · 🔥\(streak)" : "\(minutes) min focused"
  }

  /// A compact one-line summary for the popover: sessions · minutes · streak.
  private var inlineText: String {
    let sessions = count == 1 ? "1 session" : "\(count) sessions"
    var text = "\(sessions) · \(minutes) min"
    if streak > 0 { text += " · 🔥\(streak)" }
    return text
  }
}
