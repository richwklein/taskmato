//
//  TaskCardView.swift
//  Taskmato
//

import SwiftUI

/// A card-style representation of a task for the grid layout in the task picker.
///
/// Displays a completion circle, priority-prefixed title, due date (red when urgent),
/// and truncated notes. Pass `onComplete` when the task's provider supports mutation.
struct TaskCardView: View {

  let task: TaskItem
  /// Called when the user taps the completion circle. `nil` hides the button entirely.
  var onComplete: (() -> Void)?

  @State private var isHovering: Bool = false

  init(task: TaskItem, onComplete: (() -> Void)? = nil) {
    self.task = task
    self.onComplete = onComplete
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .top, spacing: 6) {
        if let complete = onComplete {
          Button(action: complete) {
            Image(systemName: isHovering ? "checkmark.circle" : "circle")
              .foregroundStyle(Color.accentColor)
          }
          .buttonStyle(.plain)
          .onHover { isHovering = $0 }
          .help("Mark done")
        }

        Text(displayTitle)
          .font(.callout)
          .lineLimit(3)
          .frame(maxWidth: .infinity, alignment: .leading)
      }

      if let due = task.dueDate {
        Text(due, format: .dateTime.month(.abbreviated).day().year())
          .font(.caption2)
          .foregroundStyle(isUrgent(due) ? Color.red : Color.secondary)
      }

      if let notes = task.notes {
        TaskNoteView(notes: notes, format: task.format)
          .lineLimit(2)
      }

      Spacer(minLength: 0)
    }
    .padding(10)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(
      RoundedRectangle(cornerRadius: 10)
        .fill(.secondary.opacity(0.1))
    )
    .contentShape(RoundedRectangle(cornerRadius: 10))
  }

  /// Returns `true` when the due date is today or in the past.
  private func isUrgent(_ date: Date) -> Bool {
    Calendar.current.isDateInToday(date) || date < Date.now
  }

  /// Priority mark (colored) prepended inline to the markdown-rendered title.
  private var displayTitle: AttributedString {
    guard !priorityMark.isEmpty else { return markdownTitle }
    var prefix = AttributedString(priorityMark + " ")
    prefix.swiftUI.foregroundColor = priorityColor
    return prefix + markdownTitle
  }

  private var markdownTitle: AttributedString {
    guard task.format == .markdown else { return AttributedString(task.title) }
    let options = AttributedString.MarkdownParsingOptions(
      interpretedSyntax: .inlineOnlyPreservingWhitespace
    )
    return (try? AttributedString(markdown: task.title, options: options))
      ?? AttributedString(task.title)
  }

  private var priorityMark: String {
    switch task.priority {
    case .highest: return "!!!"
    case .high: return "!!"
    case .medium: return "!"
    case .low, .lowest, .none: return ""
    }
  }

  private var priorityColor: Color {
    switch task.priority {
    case .highest, .high: return .red
    case .medium: return .orange
    case .low, .lowest, .none: return .primary
    }
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
  TaskCardView(task: task, onComplete: {})
    .padding()
    .frame(width: 200)
}
