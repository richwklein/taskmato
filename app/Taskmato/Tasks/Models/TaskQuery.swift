//
//  TaskQuery.swift
//  Taskmato
//

/// Encodes a task-fetch request as scope plus optional filter.
///
/// `TaskQuery` describes *what to fetch* in data terms, not which UI view triggered the
/// fetch. The registry derives sort strategy from the scope: `.singleList` preserves
/// provider section order; `.crossProvider` sorts all results globally.
enum TaskQuery: Sendable {

  /// Fetch tasks from a specific provider list.
  ///
  /// Sort is applied within each provider-defined section, preserving encounter order.
  case singleList(SelectedList)

  /// Fan out across all enabled providers, applying an optional filter.
  ///
  /// Results are sorted globally — section boundaries are not preserved.
  case crossProvider(filter: TaskFilter? = nil)

  /// `true` when tasks are fetched from all providers simultaneously.
  var isCrossProvider: Bool {
    if case .crossProvider = self { return true }
    return false
  }
}

/// A filter applied to a cross-provider fetch.
enum TaskFilter: Sendable {

  /// Include only tasks whose `dueDate` is on or before the end of today (overdue and today).
  case dueUpToToday

  /// Include only tasks whose title contains the given string (case-insensitive).
  case titleContains(String)
}
