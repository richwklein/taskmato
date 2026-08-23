//
//  TaskMetadataLabel.swift
//  Taskmato
//

import SwiftUI

/// A task's one-line metadata: the due date for active tasks, or the completed-relative
/// subtitle for completed ones.
///
/// A view of its own rather than a slot inside ``TaskRowView`` so it reads
/// `\.backgroundProminence` at its own position, the way ``PriorityGlyph`` does — an overdue
/// date is an explicit red that a selected row's accent fill would otherwise swallow.
struct TaskMetadataLabel: View {

  let presenter: TaskItemPresenter

  /// Set by `List` on an emphasized selected row, where the overdue tint stops reading.
  @Environment(\.backgroundProminence) private var prominence

  var body: some View {
    if let due = presenter.dueDate {
      Text(
        due,
        format: presenter.dueDateIncludesTime
          ? .dateTime.month(.abbreviated).day().hour().minute()
          : .dateTime.month(.abbreviated).day()
      )
      .font(.taskMetadata)
      .foregroundStyle(presenter.dueIsUrgent ? prominence.accent(.dueUrgent) : Color.secondary)
    } else if presenter.isCompleted {
      Text(presenter.completedSubtitle)
        .font(.taskMetadata)
        .foregroundStyle(.tertiary)
    }
  }
}
