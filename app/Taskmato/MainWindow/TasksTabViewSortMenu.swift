//
//  TasksTabViewSortMenu.swift
//  Taskmato
//

import SwiftUI

// MARK: - Sort menu

extension TasksTabView {

  /// Sort menu placed in the toolbar, adapting field/direction labels to the active selection.
  var sortMenu: some View {
    let isToday = registry.selection == .today
    let currentField = isToday ? settings.todaySortField : settings.taskSortField
    let currentDirection = isToday ? settings.todaySortDirection : settings.taskSortDirection

    return Menu {
      Section("Sort by") {
        ForEach(TaskSortField.allCases, id: \.self) { field in
          Button {
            if isToday {
              settings.todaySortField = field
            } else {
              settings.taskSortField = field
            }
          } label: {
            Label(
              displayName(for: field),
              systemImage: currentField == field ? "checkmark" : "")
          }
        }
      }
      Divider()
      Button {
        if isToday {
          settings.todaySortDirection = .ascending
        } else {
          settings.taskSortDirection = .ascending
        }
      } label: {
        Label(
          ascendingLabel(for: currentField),
          systemImage: currentDirection == .ascending ? "checkmark" : "")
      }
      Button {
        if isToday {
          settings.todaySortDirection = .descending
        } else {
          settings.taskSortDirection = .descending
        }
      } label: {
        Label(
          descendingLabel(for: currentField),
          systemImage: currentDirection == .descending ? "checkmark" : "")
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
