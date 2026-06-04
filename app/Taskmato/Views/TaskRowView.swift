//
//  TaskRowView.swift
//  Taskmato
//

import SwiftUI

/// A single row in the task picker list, showing a leading state button, priority-prefixed
/// title, notes, primary metadata, and optional lineage indicator.
///
/// Use ``TaskItemKind`` to distinguish active and completed tasks. Pass `lineage` when the
/// picker is in cross-provider flat mode (Today or search) to show the task's origin.
struct TaskRowView: View {

  let task: TaskItem
  let kind: TaskItemKind
  var lineage: TaskLineage?

  @State private var isHovered = false
  @State private var showDeleteConfirmation = false

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      leadingButton
      VStack(alignment: .leading, spacing: 2) {
        titleRow
        if let notes = task.notes {
          TaskNoteView(notes: notes, format: task.format)
        }
        primaryMetadata
        if let lin = lineage, !lin.isEmpty {
          lineageRow(lin)
        }
      }
      trailingButton
    }
    .padding(.vertical, 4)
    .contentShape(Rectangle())
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
          .foregroundStyle(priorityColor)
          .font(.callout)
      }
      Text(markdownTitle)
        .font(.callout)
        .foregroundStyle(isCompleted ? .secondary : .primary)
        .lineLimit(2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  @ViewBuilder
  private var primaryMetadata: some View {
    switch kind {
    case .active:
      if let due = task.dueDate {
        Text(due, format: .dateTime.month(.abbreviated).day())
          .font(.caption2)
          .foregroundStyle(isUrgent(due) ? Color.red : Color.secondary)
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

  private func isUrgent(_ date: Date) -> Bool {
    Calendar.current.isDateInToday(date) || date < Date.now
  }

  private var markdownTitle: AttributedString {
    guard task.format == .markdown else { return AttributedString(task.title) }
    let options = AttributedString.MarkdownParsingOptions(
      interpretedSyntax: .inlineOnlyPreservingWhitespace
    )
    return (try? AttributedString(markdown: task.title, options: options))
      ?? AttributedString(task.title)
  }

  private var priorityColor: Color {
    switch task.priority {
    case .highest, .high, .medium: return .orange
    case .low, .lowest, .none: return .primary
    }
  }
}
