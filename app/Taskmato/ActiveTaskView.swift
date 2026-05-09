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

  var body: some View {
    if let task = selectionStore.activeTask {
      HStack(spacing: 8) {
        leadingIndicator(for: task)

        Text(task.title)
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

  /// Returns a complete button when the provider supports mutation, or a static dot indicator otherwise.
  @ViewBuilder
  private func leadingIndicator(for task: TaskItem) -> some View {
    if let provider = registry.mutableProvider(for: task.id) {
      Button {
        Task { try? await provider.complete(task.id) }
        selectionStore.clearActiveTask()
      } label: {
        Image(systemName: "checkmark.circle")
          .font(.caption2)
          .foregroundStyle(Color.accentColor)
      }
      .buttonStyle(.plain)
      .help("Mark done")
    } else {
      Image(systemName: "circle.fill")
        .font(.caption2)
        .foregroundStyle(Color.accentColor)
    }
  }
}
