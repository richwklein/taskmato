//
//  ActiveTaskView.swift
//  Taskmato
//

import SwiftUI

/// A label row displaying the currently selected task with provider-conditional action buttons.
///
/// Hidden entirely when no task is selected.
@MainActor
struct ActiveTaskView: View {

  var selectionStore: TaskSelectionStore
  var registry: TaskRegistry

  @State private var isCompletionHovered: Bool = false

  var body: some View {
    if let task = selectionStore.activeTask {
      HStack(spacing: 8) {
        leadingIndicator(for: task)

        Text(markdownTitle(for: task))
          .font(.callout)
          .lineLimit(1)
          .frame(maxWidth: .infinity, alignment: .leading)

        Button {
          selectionStore.clearActiveTask()
        } label: {
          Image(systemName: "xmark")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help("Clear task")
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
    }
  }

  /// Returns the task title rendered as inline markdown when the task format is `.markdown`.
  private func markdownTitle(for task: TaskItem) -> AttributedString {
    guard task.format == .markdown else { return AttributedString(task.title) }
    let options = AttributedString.MarkdownParsingOptions(
      interpretedSyntax: .inlineOnlyPreservingWhitespace
    )
    return (try? AttributedString(markdown: task.title, options: options))
      ?? AttributedString(task.title)
  }

  /// Returns a complete button when the provider supports mutation, or a static dot indicator otherwise.
  @ViewBuilder
  private func leadingIndicator(for task: TaskItem) -> some View {
    if let provider = registry.mutableProvider(for: task.id) {
      Button {
        let ref = task.id
        Task {
          try? await provider.complete(ref)
          selectionStore.clearActiveTask()
        }
      } label: {
        Image(systemName: isCompletionHovered ? "checkmark.circle" : "circle")
          .font(.caption2)
          .foregroundStyle(Color.accentColor)
      }
      .buttonStyle(.plain)
      .onHover { isCompletionHovered = $0 }
      .help("Mark done")
    } else {
      Image(systemName: "circle.fill")
        .font(.caption2)
        .foregroundStyle(Color.accentColor)
    }
  }
}
