//
//  ActiveTaskView.swift
//  Taskmato
//

import SwiftUI

/// A label row displaying the currently selected task with provider-conditional action buttons.
///
/// Hidden when no task is selected. Clearing or completing mid-session shows an inline
/// confirmation row that stops the timer and routes to the task picker. A swap button
/// (active-session only) pauses the timer and opens the task picker without stopping the session.
@MainActor
struct ActiveTaskView: View {

  var engine: SessionEngine
  var selectionStore: TaskSelectionStore
  var registry: TaskRegistry
  /// When `true`, renders task notes and source link below the title.
  var showNotes: Bool = false

  @Environment(\.openWindow) private var openWindow

  @State private var isCompletionHovered: Bool = false
  @State private var pendingAction: ConfirmAction?

  private var sessionIsActive: Bool { engine.state != .idle }

  var body: some View {
    if let task = selectionStore.activeTask {
      Group {
        if let action = pendingAction {
          confirmationRow(for: action, task: task)
        } else {
          taskRow(for: task)
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
    }
  }

  // MARK: - Row variants

  private func taskRow(for task: TaskItem) -> some View {
    HStack(alignment: .top, spacing: 8) {
      leadingIndicator(for: task)

      VStack(alignment: .leading, spacing: 2) {
        Text(displayTitle(for: task))
          .font(.callout)
          .lineLimit(1)
          .frame(maxWidth: .infinity, alignment: .leading)

        if showNotes {
          if let notes = task.notes {
            TaskNoteView(notes: notes, format: task.format)
          }

          if let url = task.sourceURL, let name = registry.provider(for: task.id)?.displayName {
            Link("Open in \(name)", destination: url)
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
        }
      }

      if sessionIsActive {
        Button {
          if engine.isRunning { engine.pause() }
          NSApp.activate(ignoringOtherApps: true)
          openWindow(id: "main")
          NotificationCenter.default.post(name: .browseTasksAndPick, object: nil)
        } label: {
          Image(systemName: "arrow.triangle.swap")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help("Swap task — pauses the session and opens the task list")
      }

      Button {
        if sessionIsActive {
          pendingAction = .clear
        } else {
          selectionStore.clearActiveTask()
        }
      } label: {
        Image(systemName: "xmark")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
      .buttonStyle(.plain)
      .help("Clear task")
    }
  }

  /// An inline prompt that replaces the normal row while a destructive action awaits confirmation.
  private func confirmationRow(for action: ConfirmAction, task: TaskItem) -> some View {
    HStack(spacing: 8) {
      Image(systemName: "exclamationmark.triangle")
        .font(.caption2)
        .foregroundStyle(.secondary)

      Text(action.prompt)
        .font(.callout)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)

      Button {
        pendingAction = nil
        commit(action, task: task)
      } label: {
        Image(systemName: "checkmark")
          .font(.caption2)
          .foregroundStyle(Color.accentColor)
      }
      .buttonStyle(.plain)
      .help(action.helpConfirm)

      Button {
        pendingAction = nil
      } label: {
        Image(systemName: "xmark")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
      .buttonStyle(.plain)
      .help("Cancel")
    }
  }

  // MARK: - Leading indicator

  /// Returns a complete button when the provider supports mutation, or a static dot indicator otherwise.
  @ViewBuilder
  private func leadingIndicator(for task: TaskItem) -> some View {
    if registry.closableProvider(for: task.id) != nil {
      Button {
        if sessionIsActive {
          pendingAction = .complete
        } else {
          let ref = task.id
          Task {
            if let provider = registry.closableProvider(for: ref) {
              try? await provider.complete(ref)
            }
            selectionStore.clearActiveTask()
          }
        }
      } label: {
        Image(systemName: isCompletionHovered ? "checkmark.circle" : "circle")
          .font(.caption2)
          .foregroundStyle(Color.accentColor)
      }
      .buttonStyle(.plain)
      .onHover { isCompletionHovered = $0 }
      .help(
        sessionIsActive
          ? TaskLabel.Tooltip.markAsCompletedActive : TaskLabel.Tooltip.markAsCompleted)
    } else {
      Image(systemName: "circle.fill")
        .font(.caption2)
        .foregroundStyle(Color.accentColor)
    }
  }

  // MARK: - Action dispatch

  private func commit(_ action: ConfirmAction, task: TaskItem) {
    switch action {
    case .complete:
      guard let provider = registry.closableProvider(for: task.id) else { return }
      let ref = task.id
      engine.stop()
      Task {
        try? await provider.complete(ref)
        selectionStore.clearActiveTask()
        NotificationCenter.default.post(name: .showTasksTab, object: nil)
      }
    case .clear:
      engine.stop()
      selectionStore.clearActiveTask()
      NotificationCenter.default.post(name: .showTasksTab, object: nil)
    }
  }

  // MARK: - Text helpers

  private func displayTitle(for task: TaskItem) -> AttributedString {
    let mark = task.priority.mark
    guard !mark.isEmpty else { return task.markdownTitle }
    var prefix = AttributedString(mark + " ")
    prefix.swiftUI.foregroundColor = task.priority.accentColor
    return prefix + task.markdownTitle
  }
}

// MARK: - ConfirmAction

/// The destructive action awaiting inline confirmation.
private enum ConfirmAction {
  /// Mark the active task done and stop the session.
  case complete
  /// Clear the active task and stop the session.
  case clear

  /// Short label shown in the confirmation row.
  var prompt: String {
    switch self {
    case .complete: return "Stop & complete?"
    case .clear: return "Stop & clear?"
    }
  }

  /// Accessibility hint for the confirm button.
  var helpConfirm: String {
    switch self {
    case .complete: return "Stop timer and mark task done"
    case .clear: return "Stop timer and clear task"
    }
  }
}
