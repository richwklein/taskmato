//
//  ActiveTaskView.swift
//  Taskmato
//

import SwiftUI

/// A label row displaying the currently selected task with provider-conditional action buttons.
///
/// Hidden when no task is selected. Clearing or completing mid-session shows a confirmation
/// that stops the timer and routes to the task picker. A swap button (active-session only)
/// pauses the timer and opens the task picker without stopping the session.
@MainActor
struct ActiveTaskView: View {

  var engine: SessionEngine
  var selectionStore: TaskSelectionStore
  var registry: TaskRegistry
  /// When `true`, renders task notes and source link below the title.
  var showNotes: Bool = false

  @Environment(\.openWindow) private var openWindow

  @State private var isCompletionHovered: Bool = false
  @State private var confirmClear: Bool = false
  @State private var confirmComplete: Bool = false

  private var sessionIsActive: Bool { engine.state != .idle }

  var body: some View {
    if let task = selectionStore.activeTask {
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

            if let url = task.sourceURL {
              Link("Open in Obsidian", destination: url)
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
            NotificationCenter.default.post(name: .showTasksTab, object: nil)
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
            confirmClear = true
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
        .confirmationDialog(
          "End the current session?",
          isPresented: $confirmClear,
          titleVisibility: .visible
        ) {
          Button("Stop & Clear", role: .destructive) {
            engine.stop()
            selectionStore.clearActiveTask()
            NotificationCenter.default.post(name: .showTasksTab, object: nil)
          }
          Button("Cancel", role: .cancel) {}
        } message: {
          Text("Clearing the task will stop the timer.")
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
      .confirmationDialog(
        "End the current session?",
        isPresented: $confirmComplete,
        titleVisibility: .visible
      ) {
        Button("Stop & Complete", role: .destructive) {
          guard let task = selectionStore.activeTask,
            let provider = registry.mutableProvider(for: task.id)
          else { return }
          let ref = task.id
          engine.stop()
          Task {
            try? await provider.complete(ref)
            selectionStore.clearActiveTask()
            NotificationCenter.default.post(name: .showTasksTab, object: nil)
          }
        }
        Button("Cancel", role: .cancel) {}
      } message: {
        Text("Completing the task will stop the timer and mark it done.")
      }
    }
  }

  private func displayTitle(for task: TaskItem) -> AttributedString {
    let mark = priorityMark(for: task.priority)
    guard !mark.isEmpty else { return markdownTitle(for: task) }
    var prefix = AttributedString(mark + " ")
    prefix.swiftUI.foregroundColor = priorityColor(for: task.priority)
    return prefix + markdownTitle(for: task)
  }

  private func markdownTitle(for task: TaskItem) -> AttributedString {
    guard task.format == .markdown else { return AttributedString(task.title) }
    let options = AttributedString.MarkdownParsingOptions(
      interpretedSyntax: .inlineOnlyPreservingWhitespace
    )
    return (try? AttributedString(markdown: task.title, options: options))
      ?? AttributedString(task.title)
  }

  private func priorityMark(for priority: TaskPriority) -> String {
    switch priority {
    case .highest: return "!!!"
    case .high: return "!!"
    case .medium: return "!"
    case .low, .lowest, .none: return ""
    }
  }

  private func priorityColor(for priority: TaskPriority) -> Color {
    switch priority {
    case .highest, .high: return .red
    case .medium: return .orange
    case .low, .lowest, .none: return .primary
    }
  }

  /// Returns a complete button when the provider supports mutation, or a static dot indicator otherwise.
  @ViewBuilder
  private func leadingIndicator(for task: TaskItem) -> some View {
    if let provider = registry.mutableProvider(for: task.id) {
      Button {
        if sessionIsActive {
          confirmComplete = true
        } else {
          let ref = task.id
          Task {
            try? await provider.complete(ref)
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
      .help(sessionIsActive ? "Complete task (will stop timer)" : "Mark done")
    } else {
      Image(systemName: "circle.fill")
        .font(.caption2)
        .foregroundStyle(Color.accentColor)
    }
  }
}
