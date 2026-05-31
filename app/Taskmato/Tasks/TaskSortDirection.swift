//
//  TaskSortDirection.swift
//  Taskmato
//

import Foundation

/// The direction in which tasks are sorted.
enum TaskSortDirection: String, CaseIterable, Sendable {

  /// Sort from smallest to largest (e.g., earliest date first, lowest priority first, A → Z).
  case ascending

  /// Sort from largest to smallest (e.g., latest date first, highest priority first, Z → A).
  case descending
}
