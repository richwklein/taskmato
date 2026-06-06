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

extension TaskSortField {

  /// Display name shown in sort menus and toolbar items.
  var displayName: String {
    switch self {
    case .dueDate: return "Due Date"
    case .priority: return "Priority"
    case .title: return "Title"
    case .creationDate: return "Creation Date"
    }
  }

  /// The natural sort direction to apply when this field is first selected.
  var defaultSortDirection: TaskSortDirection {
    switch self {
    case .dueDate, .creationDate, .title: return .ascending
    case .priority: return .descending
    }
  }

  /// Label for the ascending direction of this sort field.
  var ascendingLabel: String {
    switch self {
    case .dueDate, .creationDate: return "Earliest First"
    case .priority: return "Lowest First"
    case .title: return "A → Z"
    }
  }

  /// Label for the descending direction of this sort field.
  var descendingLabel: String {
    switch self {
    case .dueDate, .creationDate: return "Latest First"
    case .priority: return "Highest First"
    case .title: return "Z → A"
    }
  }
}
