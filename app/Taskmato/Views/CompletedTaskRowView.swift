//
//  CompletedTaskRowView.swift
//  Taskmato
//

import SwiftUI

/// A single row for a completed task in the inline completed section.
///
/// Shows a filled `checkmark.circle.fill` restore button, a muted title, and a subtitle
/// with the list name and relative completion time. On hover, an optional trash button
/// appears for providers that support permanent deletion.
struct CompletedTaskRowView: View {

  let task: TaskItem
  /// Called when the user clicks the filled circle to restore the task.
  var onRestore: () -> Void
  /// Called when the user confirms permanent deletion. `nil` hides the trash button.
  var onDelete: (() -> Void)?

  @State private var isHovering: Bool = false
  @State private var showDeleteConfirmation: Bool = false

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Button(action: onRestore) {
        Image(systemName: "checkmark.circle.fill")
          .foregroundStyle(Color.accentColor)
      }
      .buttonStyle(.plain)
      .help(TaskLabel.Tooltip.restore)

      VStack(alignment: .leading, spacing: 2) {
        Text(task.title)
          .font(.callout)
          .foregroundStyle(.secondary)
          .lineLimit(2)
          .frame(maxWidth: .infinity, alignment: .leading)

        Text(subtitle)
          .font(.caption2)
          .foregroundStyle(.tertiary)
      }

      if isHovering, let delete = onDelete {
        Button {
          showDeleteConfirmation = true
        } label: {
          Image(systemName: "trash")
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help(TaskLabel.Tooltip.deletePermanently)
        .confirmationDialog("Delete this task permanently?", isPresented: $showDeleteConfirmation) {
          Button("Delete", role: .destructive) { delete() }
          Button("Cancel", role: .cancel) {}
        }
      }
    }
    .padding(.vertical, 4)
    .contentShape(Rectangle())
    .onHover { isHovering = $0 }
  }

  private var subtitle: String {
    let listPart = task.list?.name
    let datePart = task.completedAt.map {
      RelativeDateTimeFormatter().localizedString(for: $0, relativeTo: Date())
    }
    switch (listPart, datePart) {
    case (let list?, let date?): return "\(list) · \(date)"
    case (let list?, nil): return list
    case (nil, let date?): return date
    case (nil, nil): return "Unknown date"
    }
  }
}
