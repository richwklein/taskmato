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

  /// The content format the created/updated task should use, stamped from
  /// `WritableTaskProvider.contentFormat` before submission.
  var format: ContentFormat = .markdown

  /// Priority level.
  var priority: TaskPriority = .none

  /// Due date, or `nil` if no due date is set.
  var dueDate: Date?

  /// Whether `dueDate` carries a meaningful time-of-day, or is date-only.
  var dueDateIncludesTime: Bool = false

  /// The provider-local list ID this task should belong to, or `nil` for the default list.
  var listID: String?

  /// An optional sub-grouping within the target list (e.g. a markdown heading in Obsidian).
  /// `nil` targets the list's top level. Providers without sections ignore this field.
  var section: String?
}
