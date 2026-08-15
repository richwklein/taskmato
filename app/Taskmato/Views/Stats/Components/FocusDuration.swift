//
//  FocusDuration.swift
//  Taskmato
//

import Foundation

/// Formats focus durations as compact labels for the stats views and the session footers.
///
/// Floored at every boundary, so a phase stopped at 24m37s never reads as a completed 25m
/// pomodoro. Sub-minute totals are real recordings — ADR-0009 credits any phase above a 30 s
/// floor, and a mid-phase task swap can close a slice of a few seconds — so they render in
/// seconds rather than `0m`. Exactly zero is the one exception: it reads as `"0m"`, which says
/// "no time" in a way `"0s"` does not.
///
/// - `>= 1h` → `"1h 30m"`, or `"2h"` on the hour
/// - `>= 1m` → `"25m"`
/// - `> 0`   → `"45s"`
/// - `== 0`  → `"0m"`
enum FocusDuration {

  /// Formats a duration in seconds per the ladder documented on ``FocusDuration``.
  static func label(seconds: TimeInterval) -> String {
    let total = Int(seconds)
    guard total > 0 else { return "0m" }
    if total < 60 { return "\(total)s" }
    let minutes = total / 60
    guard minutes >= 60 else { return "\(minutes)m" }
    let hours = minutes / 60
    let mins = minutes % 60
    return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
  }
}
