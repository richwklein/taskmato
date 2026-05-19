//
//  TaskCardView.swift
//  Taskmato
//

import SwiftUI

/// A card-style task cell for use in the grid view layout.
///
/// Displays a priority-colored accent bar, a two-line title, and an optional due date
/// with overdue color. A completion button is shown when `onComplete` is provided.
struct TaskCardView: View {

  let task: TaskItem
  /// Called when the user taps the completion circle. `nil` hides the button.
  var onComplete: (() -> Void)?

  @State private var isHovering: Bool = false

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .top) {
        RoundedRectangle(cornerRadius: 2)
          .fill(priorityColor)
          .frame(width: 4, height: 36)

        Text(task.title)
          .font(.callout)
          .lineLimit(2)
          .frame(maxWidth: .infinity, alignment: .leading)
          .multilineTextAlignment(.leading)
      }

      HStack {
        if let due = task.dueDate {
          Text(due, format: .dateTime.month(.abbreviated).day())
            .font(.caption2)
            .foregroundStyle(dueDateColor(for: due))
        }

        Spacer()

        if let complete = onComplete {
          Button(action: complete) {
            Image(systemName: isHovering ? "checkmark.circle" : "circle")
              .foregroundStyle(Color.accentColor)
          }
          .buttonStyle(.plain)
          .onHover { isHovering = $0 }
          .help("Mark done")
        }
      }
    }
    .padding(10)
    .background(.background.secondary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .strokeBorder(.separator, lineWidth: 0.5)
    )
  }

  private func dueDateColor(for due: Date) -> Color {
    let today = Calendar.current.startOfDay(for: Date())
    if Calendar.current.isDateInToday(due) { return .orange }
    if due < today { return .red }
    return .secondary
  }

  private var priorityColor: Color {
    switch task.priority {
    case .highest, .high: return .red
    case .medium: return .orange
    case .low, .lowest, .none: return .clear
    }
  }
}
