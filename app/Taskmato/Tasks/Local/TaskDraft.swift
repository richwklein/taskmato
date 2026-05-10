//
//  TaskDraft.swift
//  Taskmato
//

import Foundation

/// Mutable form state for creating or editing a ``LocalTask``.
///
/// Passed to ``LocalProvider/addTask(_:)`` and ``LocalProvider/updateTask(_:draft:)``
/// to apply user input to the task store without exposing the full ``LocalTask`` model
/// to the view layer.
struct TaskDraft {

  /// The task title. Must be non-empty before submission.
  var title: String = ""

  /// Optional notes for the task.
  var notes: String = ""

  /// Priority level.
  var priority: TaskPriority = .none

  /// Due date, or `nil` if no due date is set.
  var dueDate: Date?

  /// The list this task should belong to, or `nil` for uncategorized.
  var listID: UUID?
}
