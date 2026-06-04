//
//  CompletedTaskCardView.swift
//  Taskmato
//

import SwiftUI

/// A card-style representation of a completed task for the grid layout.
///
/// Mirrors the shape of ``TaskCardView``: filled `checkmark.circle.fill` restore button,
/// muted title, and a completion subtitle (list · relative date) where the due date
/// normally appears. On hover, an optional trash button appears in the top-right corner.
struct CompletedTaskCardView: View {

  let task: TaskItem
  /// Called when the user clicks the filled circle to restore the task.
  var onRestore: () -> Void
  /// Called when the user confirms permanent deletion. `nil` hides the trash button.
  var onDelete: (() -> Void)?

  @State private var isHovering: Bool = false
  @State private var showDeleteConfirmation: Bool = false

  var body: some View {
    ZStack(alignment: .topTrailing) {
      HStack(alignment: .top, spacing: 6) {
        Button(action: onRestore) {
          Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(Color.accentColor)
        }
        .buttonStyle(.plain)
        .help(TaskLabel.Tooltip.restore)

        VStack(alignment: .leading, spacing: 4) {
          Text(task.title)
            .font(.callout)
            .foregroundStyle(.secondary)
            .lineLimit(3)
            .frame(maxWidth: .infinity, alignment: .leading)

          Text(subtitle)
            .font(.caption2)
            .foregroundStyle(.tertiary)

          if let notes = task.notes {
            TaskNoteView(notes: notes, format: task.format)
              .lineLimit(2)
          }

          Spacer(minLength: 0)
        }
      }
      .padding(10)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

      if isHovering, let delete = onDelete {
        Button {
          showDeleteConfirmation = true
        } label: {
          Image(systemName: "trash")
            .foregroundStyle(.secondary)
            .padding(8)
        }
        .buttonStyle(.plain)
        .help(TaskLabel.Tooltip.deletePermanently)
        .confirmationDialog("Delete this task permanently?", isPresented: $showDeleteConfirmation) {
          Button("Delete", role: .destructive) { delete() }
          Button("Cancel", role: .cancel) {}
        }
      }
    }
    .background(
      RoundedRectangle(cornerRadius: 10)
        .fill(.secondary.opacity(0.1))
    )
    .contentShape(RoundedRectangle(cornerRadius: 10))
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
