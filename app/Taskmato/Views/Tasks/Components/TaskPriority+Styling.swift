//
//  TaskPriority+Styling.swift
//  Taskmato
//

import SwiftUI

extension TaskPriority {

  /// The accent color used to tint priority icons in task views.
  var accentColor: Color {
    switch self {
    case .highest, .high, .medium: return .priorityHigh
    case .low, .lowest, .none: return .priorityNeutral
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
