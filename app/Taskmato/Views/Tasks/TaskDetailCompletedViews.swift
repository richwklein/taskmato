//
//  TaskDetailCompletedViews.swift
//  Taskmato
//

import SwiftUI

/// Completed-task row builder for `TaskDetailView`, plus the active-task list section builder —
/// moved here to keep `TaskDetailView`'s own type body under the repo's length limit.
extension TaskDetailView {

  /// A ``TaskRowView``-backed section of `section`'s active tasks, wired to the row context menu.
  ///
  /// Rows carry no tap gesture: `List` owns selection, so the platform handles clicking,
  /// arrow-key movement, and context-menu targeting, and marks the row accessibility-selected.
  @ViewBuilder
  func listSection(for section: TaskSection) -> some View {
    SwiftUI.Section {
      SwiftUI.ForEach(section.tasks) { task in
        TaskRowView(
          task: task,
          kind: activeKind(for: task),
          lineage: lineage(for: task)
        )
        .contextMenu { taskContextMenu(for: task) }
      }
    } header: {
      if shouldShowHeader(section) {
        Text(section.header).font(.sectionHeader)
      }
    }
  }

  /// A ``TaskRowView`` wired to this view's restore and delete handlers.
  func completedRow(_ task: TaskItem) -> some View {
    TaskRowView(
      task: task,
      kind: completedKind(for: task),
      lineage: lineage(for: task)
    )
    .contextMenu { completedTaskContextMenu(for: task) }
  }
}
