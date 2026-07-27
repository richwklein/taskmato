//
//  TaskPriority+Styling.swift
//  Taskmato
//

import SwiftUI

extension TaskPriority {

  /// The accent color used to tint priority icons in task views.
  ///
  /// Tint completes the glyph-distinct `icon` mapping: `highest` gets its own emphatic tint,
  /// the elevated band shares `priorityHigh`, `low` is neutral, and `lowest` dims to
  /// `.secondary` so it reads below `low` while still showing its shared glyph.
  var accentColor: Color {
    switch self {
    case .highest: return .priorityHighest
    case .high, .medium: return .priorityHigh
    case .low, .none: return .priorityNeutral
    case .lowest: return .secondary
    }
  }

  /// A short text mark prepended to the task title in the active-task label.
  var mark: String {
    switch self {
    case .highest: return "!!!"
    case .high: return "!!"
    case .medium: return "!"
    case .low, .lowest, .none: return ""
    }
  }
}
