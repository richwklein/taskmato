//
//  FocusDuration.swift
//  Taskmato
//

import Foundation

/// Formats focus durations as compact `"Xh Ym"` / `"Xm"` labels for the stats UI.
enum FocusDuration {

  /// Formats whole minutes as `"Xh Ym"` when ≥ 60, `"Xh"` on the hour, otherwise `"Xm"`.
  static func label(minutes: Int) -> String {
    if minutes >= 60 {
      let hours = minutes / 60
      let mins = minutes % 60
      return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
    }
    return "\(minutes)m"
  }

  /// Formats a duration in seconds by truncating to whole minutes.
  static func label(seconds: TimeInterval) -> String {
    label(minutes: Int(seconds / 60))
  }
}
