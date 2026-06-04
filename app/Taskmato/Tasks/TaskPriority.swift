//
//  TaskPriority.swift
//  Taskmato
//

import Foundation

/// The priority level of a task, aligned with the obsidian-tasks emoji format.
enum TaskPriority: Int, Codable, Comparable, CaseIterable, Sendable {

  /// No priority assigned.
  case none = 0
  /// Lowest priority (⏬).
  case lowest = 1
  /// Low priority (🔽).
  case low = 2
  /// Medium priority (🔼).
  case medium = 3
  /// High priority (⏫).
  case high = 4
  /// Highest priority (🔺).
  case highest = 5

  static func < (lhs: TaskPriority, rhs: TaskPriority) -> Bool {
    lhs.rawValue < rhs.rawValue
  }

  /// SF Symbol name for this priority level, or `nil` for `.none`.
  var icon: String? {
    switch self {
    case .none: return nil
    case .lowest, .low: return "exclamationmark"
    case .medium: return "exclamationmark.2"
    case .high, .highest: return "exclamationmark.3"
    }
  }
}
