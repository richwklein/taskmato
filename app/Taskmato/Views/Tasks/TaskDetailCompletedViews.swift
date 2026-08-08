//
//  TaskDetailCompletedViews.swift
//  Taskmato
//

import SwiftUI

/// Completed-task row and card builders for `TaskDetailView`.
extension TaskDetailView {

  /// A ``TaskRowView`` wired to this view's restore and delete handlers.
  func completedRow(_ task: TaskItem) -> some View {
    TaskRowView(
      task: task,
      kind: completedKind(for: task),
      lineage: lineage(for: task)
    )
    .listRowBackground(selectionBackground(for: task))
    .onTapGesture {
      selection = task.id
      focusTaskContent()
    }
    .accessibilityAddTraits(selection == task.id ? .isSelected : [])
    .contextMenu { completedTaskContextMenu(for: task) }
  }

  /// A ``TaskCardView`` wired to this view's restore and delete handlers.
  func completedCard(_ task: TaskItem) -> some View {
    TaskCardView(
      task: task,
      kind: completedKind(for: task),
      lineage: lineage(for: task),
      isSelected: selection == task.id,
      isSelectionFocused: isTaskContentFocused
    )
    .contentShape(RoundedRectangle.card)
    .onTapGesture {
      selection = task.id
      focusTaskContent()
    }
    .contextMenu { completedTaskContextMenu(for: task) }
  }
}
