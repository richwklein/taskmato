//
//  TaskDetailSortMenu.swift
//  Taskmato
//

import SwiftUI

// MARK: - Sort menu

extension TaskDetailView {

  /// Sort menu placed in the toolbar.
  var sortMenu: some View {
    Menu {
      TaskSortMenuContent(settings: settings)
    } label: {
      Label(AppLabels.View.sort.title, systemImage: AppLabels.View.sort.systemImage)
    }
    .help("Sort tasks")
  }
}

// MARK: - Shared sort menu content

/// The sort-by field list and direction toggle shared by the Tasks toolbar sort menu and the
/// View → Sort By command, so field order, defaults, and checkmarked state cannot drift between
/// the two surfaces.
///
/// Selecting a field also resets the direction to its natural default so the menu always lands
/// in a sensible state: due date and creation date default to earliest-first, priority defaults
/// to highest-first, title defaults to A→Z.
struct TaskSortMenuContent: View {

  /// Backs the sort field and direction state read and written by this menu's controls.
  var settings: AppSettings
  /// Disables every item, matching the individual-item disabling `TaskmatoCommands` needs so
  /// menu items re-validate and grey out live when the task surface leaves the scene (#426).
  var disabled: Bool = false

  var body: some View {
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
        .disabled(disabled)
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
    .disabled(disabled)
    Button {
      settings.taskSortDirection = .descending
    } label: {
      Label(
        settings.taskSortField.descendingLabel,
        systemImage: settings.taskSortDirection == .descending ? "checkmark" : "")
    }
    .disabled(disabled)
  }
}
