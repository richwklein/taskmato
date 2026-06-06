//
//  TaskCardView.swift
//  Taskmato
//

import SwiftUI

/// A card-style representation of a task for the grid layout in the task picker.
///
/// Use ``TaskItemKind`` to distinguish active and completed tasks. Pass `lineage` when the
/// picker is in cross-provider flat mode (Today or search) to show the task's origin.
struct TaskCardView: View {

  let task: TaskItem
  let kind: TaskItemKind
  var lineage: TaskLineage?

  @State private var isHovered = false
  @State private var showDeleteConfirmation = false

  var body: some View {
    HStack(alignment: .top, spacing: 6) {
      leadingButton
      VStack(alignment: .leading, spacing: 4) {
        titleRow
        if let notes = task.notes {
          TaskNoteView(notes: notes, format: task.format)
            .lineLimit(2)
        }
        primaryMetadata
        if let lin = lineage, !lin.isEmpty {
          lineageRow(lin)
        }
        Spacer(minLength: 0)
      }
      trailingButton
    }
    .padding(10)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(
      RoundedRectangle(cornerRadius: 10)
        .fill(.secondary.opacity(0.1))
    )
    .contentShape(RoundedRectangle(cornerRadius: 10))
    .onHover { hover in
      if case .completed = kind { isHovered = hover }
    }
    .confirmationDialog(
      "Delete this task permanently?", isPresented: $showDeleteConfirmation
    ) {
      Button("Delete", role: .destructive) {
        if case .completed(_, let onDelete) = kind { onDelete?() }
      }
      Button("Cancel", role: .cancel) {}
    }
  }

  @ViewBuilder
  private var leadingButton: some View {
    switch kind {
    case .active(let onComplete):
      if let complete = onComplete {
        Button(action: complete) {
          Image(systemName: isHovered ? "checkmark.circle" : "circle")
            .foregroundStyle(Color.accentColor)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(TaskLabel.Tooltip.markAsCompleted)
      }
    case .completed(let onRestore, _):
      Button(action: onRestore) {
        Image(systemName: "checkmark.circle.fill")
          .foregroundStyle(Color.accentColor)
      }
      .buttonStyle(.plain)
      .help(TaskLabel.Tooltip.restore)
    }
  }

  private var titleRow: some View {
    HStack(alignment: .firstTextBaseline, spacing: 3) {
      if let icon = task.priority.icon {
        Image(systemName: icon)
          .foregroundStyle(task.priority.accentColor)
          .font(.callout)
      }
      TaskMarkdownTitle(task: task, isCompleted: isCompleted, lineLimit: 3)
    }
  }

  @ViewBuilder
  private var primaryMetadata: some View {
    switch kind {
    case .active:
      if let due = task.dueDate {
        Text(due, format: .dateTime.month(.abbreviated).day().year())
          .font(.caption2)
          .foregroundStyle(due.isUrgentDueDate ? Color.red : Color.secondary)
      }
    case .completed:
      Text(completedSubtitle)
        .font(.caption2)
        .foregroundStyle(.tertiary)
    }
  }

  private func lineageRow(_ lin: TaskLineage) -> some View {
    HStack(spacing: 3) {
      if let icon = lin.providerIcon {
        Image(systemName: icon)
      }
      if let ctx = lin.contextLabel {
        if lin.providerIcon != nil {
          Image(systemName: "chevron.right")
        }
        Text(ctx)
      }
    }
    .font(.caption2)
    .foregroundStyle(.tertiary)
  }

  @ViewBuilder
  private var trailingButton: some View {
    if case .completed(_, _?) = kind, isHovered {
      Button {
        showDeleteConfirmation = true
      } label: {
        Image(systemName: "trash")
          .foregroundStyle(.secondary)
      }
      .buttonStyle(.plain)
      .help(TaskLabel.Tooltip.deletePermanently)
    }
  }

  private var isCompleted: Bool {
    if case .completed = kind { return true }
    return false
  }

  private var completedSubtitle: String {
    task.completedAt.map {
      RelativeDateTimeFormatter().localizedString(for: $0, relativeTo: Date())
    } ?? "Unknown date"
  }
}

#Preview {
  let task = TaskItem(
    id: TaskRef(providerID: "local", nativeID: "1"),
    title: "Create a support metrics dashboard and wiki",
    notes: "Build out a dashboard of our support metrics once we have some statistics.",
    format: .plainText,
    priority: .high,
    dueDate: Calendar.current.date(byAdding: .day, value: -3, to: .now)
  )
  TaskCardView(task: task, kind: .active(onComplete: {}))
    .padding()
    .frame(width: 200)
}
