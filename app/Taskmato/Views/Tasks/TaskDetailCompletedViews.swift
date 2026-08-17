//
//  TaskDetailCompletedViews.swift
//  Taskmato
//

import SwiftUI

/// Completed-task row builder for `TaskDetailView`, plus the active-task list section builder —
/// moved here to keep `TaskDetailView`'s own type body under the repo's length limit.
extension TaskDetailView {

  /// A ``TaskRowView``-backed section of `section`'s active tasks, wired to selection surface,
  /// selection state, and the row context menu.
  @ViewBuilder
  func listSection(for section: TaskSection) -> some View {
    SwiftUI.Section {
      SwiftUI.ForEach(section.tasks) { task in
        attachSelectionSurface(
          to:
            TaskRowView(
              task: task,
              kind: activeKind(for: task),
              lineage: lineage(for: task)
            )
            .onTapGesture {
              selection = task.id
              focusTaskContent()
            }
            .simultaneousGesture(TapGesture(count: 2).onEnded { select(task) })
            .accessibilityAddTraits(selection == task.id ? .isSelected : [])
            .contextMenu { taskContextMenu(for: task) },
          for: task
        )
      }
    } header: {
      if shouldShowHeader(section) {
        Text(section.header).font(.sectionHeader)
      }
    }
  }

  /// A ``TaskRowView`` wired to this view's restore and delete handlers.
  func completedRow(_ task: TaskItem) -> some View {
    attachSelectionSurface(
      to:
        TaskRowView(
          task: task,
          kind: completedKind(for: task),
          lineage: lineage(for: task)
        )
        .onTapGesture {
          selection = task.id
          focusTaskContent()
        }
        .accessibilityAddTraits(selection == task.id ? .isSelected : [])
        .contextMenu { completedTaskContextMenu(for: task) },
      for: task
    )
  }
}
