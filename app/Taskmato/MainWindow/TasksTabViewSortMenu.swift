//
//  TasksTabViewSortMenu.swift
//  Taskmato
//

import SwiftUI

// MARK: - Sort menu

extension TasksTabView {

  /// Sort menu placed in the toolbar.
  ///
  /// Selecting a field also resets the direction to its natural default so the
  /// picker always lands in a sensible state: due date and creation date default
  /// to earliest-first, priority defaults to highest-first, title defaults to A→Z.
  var sortMenu: some View {
    Menu {
      Section("Sort by") {
        ForEach(TaskSortField.allCases, id: \.self) { field in
          Button {
            settings.taskSortField = field
            settings.taskSortDirection = defaultDirection(for: field)
          } label: {
            Label(
              displayName(for: field),
              systemImage: settings.taskSortField == field ? "checkmark" : "")
          }
        }
      }
      Divider()
      Button {
        settings.taskSortDirection = .ascending
      } label: {
        Label(
          ascendingLabel(for: settings.taskSortField),
          systemImage: settings.taskSortDirection == .ascending ? "checkmark" : "")
      }
      Button {
        settings.taskSortDirection = .descending
      } label: {
        Label(
          descendingLabel(for: settings.taskSortField),
          systemImage: settings.taskSortDirection == .descending ? "checkmark" : "")
      }
    } label: {
      Label("Sort", systemImage: "arrow.up.arrow.down")
    }
    .help("Sort tasks")
  }

  func displayName(for field: TaskSortField) -> String {
    switch field {
    case .dueDate: return "Due Date"
    case .priority: return "Priority"
    case .title: return "Title"
    case .creationDate: return "Creation Date"
    }
  }

  /// The natural sort direction for a field: used when switching fields so the
  /// user always lands in the most intuitive order without an extra click.
  func defaultDirection(for field: TaskSortField) -> TaskSortDirection {
    switch field {
    case .dueDate, .creationDate, .title: return .ascending
    case .priority: return .descending
    }
  }

  func ascendingLabel(for field: TaskSortField) -> String {
    switch field {
    case .dueDate, .creationDate: return "Earliest First"
    case .priority: return "Lowest First"
    case .title: return "A → Z"
    }
  }

  func descendingLabel(for field: TaskSortField) -> String {
    switch field {
    case .dueDate, .creationDate: return "Latest First"
    case .priority: return "Highest First"
    case .title: return "Z → A"
    }
  }
}
