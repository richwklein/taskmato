//
//  TaskRowView.swift
//  Taskmato
//

import SwiftUI

/// A single row in the task picker list, showing a leading state button, priority-prefixed
/// title, notes, primary metadata, and optional lineage indicator.
///
/// Use ``TaskItemKind`` to distinguish active and completed tasks. Pass `lineage` when the
/// picker is in cross-provider flat mode (Today or search) to show the task's origin. All
/// non-layout logic lives in ``TaskItemPresenter``; this view only arranges the slots.
///
/// The row draws no surface of its own: `List` owns selection, so the platform paints the
/// selected and unfocused-selected appearances and inverts row content to match.
struct TaskRowView: View {

  let task: TaskItem
  let kind: TaskItemKind
  var lineage: TaskLineage?

  @State private var completionHover = false
  @State private var rowHover = false
  @State private var showDeleteConfirmation = false

  private var presenter: TaskItemPresenter {
    TaskItemPresenter(task: task, kind: kind, lineage: lineage)
  }

  var body: some View {
    HStack(alignment: .top, spacing: .contentGap) {
      TaskStateButtonView(presenter: presenter, isHovered: $completionHover)
      HStack(alignment: .firstTextBaseline, spacing: .iconLabel) {
        PriorityGlyph(priority: task.priority)
        VStack(alignment: .leading, spacing: .stackTight) {
          TaskMarkdownTitle(task: task, isCompleted: presenter.isCompleted, lineLimit: 2)
          if let notes = task.notes {
            TaskNoteView(notes: notes, format: task.format)
          }
          metadata
          if let lineage = presenter.displayLineage {
            TaskLineageRow(lineage: lineage)
          }
        }
      }
      TaskDeleteButtonView(
        presenter: presenter, isHovered: rowHover, showConfirmation: $showDeleteConfirmation)
    }
    .padding(.vertical, .rowVertical)
    .contentShape(Rectangle())
    .onHover { rowHover = $0 }
    .confirmationDialog(
      "Delete this task permanently?", isPresented: $showDeleteConfirmation
    ) {
      Button("Delete", role: .destructive) { presenter.onDelete?() }
      Button("Cancel", role: .cancel) {}
    }
  }

  /// The due date (active tasks) or completed-relative subtitle (completed tasks).
  @ViewBuilder
  private var metadata: some View {
    if let due = presenter.dueDate {
      Text(
        due,
        format: presenter.dueDateIncludesTime
          ? .dateTime.month(.abbreviated).day().hour().minute()
          : .dateTime.month(.abbreviated).day()
      )
      .font(.taskMetadata)
      .foregroundStyle(presenter.dueIsUrgent ? Color.dueUrgent : Color.secondary)
    } else if presenter.isCompleted {
      Text(presenter.completedSubtitle)
        .font(.taskMetadata)
        .foregroundStyle(.tertiary)
    }
  }
}
