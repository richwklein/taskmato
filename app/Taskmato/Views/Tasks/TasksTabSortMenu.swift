//
//  TasksTabSortMenu.swift
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
            settings.taskSortDirection = field.defaultSortDirection
          } label: {
            Label(
              field.displayName,
              systemImage: settings.taskSortField == field ? "checkmark" : "")
          }
        }
      }
      Divider()
      Button {
        settings.taskSortDirection = .ascending
      } label: {
        Label(
          settings.taskSortField.ascendingLabel,
          systemImage: settings.taskSortDirection == .ascending ? "checkmark" : "")
      }
      Button {
        settings.taskSortDirection = .descending
      } label: {
        Label(
          settings.taskSortField.descendingLabel,
          systemImage: settings.taskSortDirection == .descending ? "checkmark" : "")
      }
    } label: {
      Label(AppLabels.View.sort.title, systemImage: AppLabels.View.sort.systemImage)
    }
    .help("Sort tasks")
  }
}
