//
//  TaskSortField.swift
//  Taskmato
//

import Foundation

/// The field used to sort tasks within a list or view.
enum TaskSortField: String, CaseIterable, Sendable {

  /// Sort by the task's due date.
  case dueDate

  /// Sort by the task's priority.
  case priority

  /// Sort by the task's title.
  case title

  /// Sort by the wall-clock time the task was created in its source provider.
  case creationDate
}
