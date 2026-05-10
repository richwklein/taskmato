//
//  TaskRowView.swift
//  Taskmato
//

import SwiftUI

/// A single row in the task picker list, showing a completion button, priority-prefixed title,
/// and due date.
///
/// Pass `onComplete` when the task's provider supports mutation; the row shows an open circle
/// button that reveals a checkmark on hover.
struct TaskRowView: View {

  let task: TaskItem
  /// Called when the user taps the completion circle. `nil` hides the button entirely.
  var onComplete: (() -> Void)?

  @State private var isHovering: Bool = false

  init(task: TaskItem, onComplete: (() -> Void)? = nil) {
    self.task = task
    self.onComplete = onComplete
  }

  var body: some View {
    HStack(spacing: 8) {
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
        .lineLimit(2)
        .frame(maxWidth: .infinity, alignment: .leading)

      if let due = task.dueDate {
        Text(due, format: .dateTime.month(.abbreviated).day())
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
    }
    .padding(.vertical, 4)
    .contentShape(Rectangle())
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
