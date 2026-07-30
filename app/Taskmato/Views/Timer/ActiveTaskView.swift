//
//  ActiveTaskView.swift
//  Taskmato
//

import SwiftUI

/// The surface variant an ``ActiveTaskView`` renders for.
enum ActiveTaskStyle {
  /// Companion popover and in-window strip: radio + single-line title only.
  case compact
  /// Timer destination: radio + title + notes/source link + swap + clear.
  case detail
}

/// A label row displaying the currently selected task with provider-conditional action buttons.
///
/// Hidden when no task is selected. Clearing or completing mid-session shows an inline
/// confirmation row that stops the timer and routes to the task picker. A swap button
/// (active-session only) pauses the timer and opens the task picker without stopping the session.
/// The same view backs the popover, the in-window strip, and the Timer destination; ``style``
/// drives which affordances render and whether completing/clearing navigates the window.
@MainActor
struct ActiveTaskView: View {

  var engine: SessionEngine
  var selectionStore: TaskSelectionStore
  var registry: ProviderRegistry
  var nav: MainNavigation
  var errorPresenter: ErrorPresenter
  /// The surface this instance renders for; drives title styling, secondary affordances, and
  /// post-commit navigation.
  var style: ActiveTaskStyle = .detail
  /// Invoked when the user clicks the title; `nil` renders the title as plain, non-interactive text.
  var onSelect: (() -> Void)?

  @State private var isCompletionHovered: Bool = false
  @State private var pendingAction: ActiveTaskConfirmAction?

  private var sessionIsActive: Bool { engine.state != .idle }

  var body: some View {
    if let task = selectionStore.activeTask {
      if let action = pendingAction {
        ActiveTaskConfirmRow(
          action: action,
          onConfirm: {
            pendingAction = nil
            commit(action, task: task)
          },
          onCancel: { pendingAction = nil }
        )
      } else {
        taskRow(for: task)
      }
    }
  }

  // MARK: - Row variants

  private func taskRow(for task: TaskItem) -> some View {
    // Baseline (not top) alignment so the small `.caption2` radio and trailing controls sit
    // optically centered on the title line, rather than riding above it.
    HStack(alignment: .firstTextBaseline, spacing: .contentGap) {
      leadingIndicator(for: task)

      titleBlock(for: task)

      if style == .detail {
        if sessionIsActive {
          Button {
            if engine.isRunning { engine.pause() }
            nav.openMainWindow()
            nav.showTasks()
          } label: {
            Image(systemName: "arrow.triangle.swap")
              .foregroundStyle(.secondary)
          }
          .buttonStyle(.plain)
          .help(AppLabels.Tooltip.swapTask)
        }

        Button {
          if sessionIsActive {
            pendingAction = .clear
          } else {
            selectionStore.clearActiveTask()
          }
        } label: {
          Image(systemName: "xmark")
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help(AppLabels.Tooltip.clearTask)
      }
    }
  }

  /// The title portion of the row: a hanging priority glyph beside a single-line, content-width
  /// title for ``ActiveTaskStyle/compact`` (so the strip's inline countdown can sit snug beside
  /// it), or the same glyph plus a filling title with notes and a ``TaskSourceBadge`` for
  /// ``ActiveTaskStyle/detail``, matching ``TaskRowView``.
  @ViewBuilder
  private func titleBlock(for task: TaskItem) -> some View {
    switch style {
    case .compact:
      HStack(alignment: .firstTextBaseline, spacing: .iconLabel) {
        PriorityGlyph(priority: task.priority)
        if let onSelect {
          Button(action: onSelect) {
            TaskMarkdownTitle(task: task, lineLimit: 1, fill: false)
              .contentShape(.rect)
          }
          .buttonStyle(.plain)
        } else {
          TaskMarkdownTitle(task: task, lineLimit: 1, fill: false)
        }
      }
    case .detail:
      HStack(alignment: .firstTextBaseline, spacing: .iconLabel) {
        PriorityGlyph(priority: task.priority)
        VStack(alignment: .leading, spacing: .stackTight) {
          TaskMarkdownTitle(task: task, lineLimit: 1)

          if let notes = task.notes {
            TaskNoteView(notes: notes, format: task.format)
          }

          if let url = task.sourceURL, let provider = registry.provider(for: task.id) {
            TaskSourceBadge(url: url, name: provider.displayName, icon: provider.icon)
          }
        }
      }
    }
  }

  // MARK: - Leading indicator

  /// Returns a completion button when the provider supports mutation, or nothing otherwise.
  @ViewBuilder
  private func leadingIndicator(for task: TaskItem) -> some View {
    if registry.closableProvider(for: task.id) != nil {
      TaskCompletionButton(
        action: { completeTapped(task) },
        label: sessionIsActive
          ? AppLabels.Tooltip.markAsCompletedActive : AppLabels.Tooltip.markAsCompleted,
        isHovered: $isCompletionHovered
      )
    }
  }

  /// Handles a tap on the completion circle: confirms first during a live session, otherwise
  /// completes the task through its provider and clears the active selection.
  private func completeTapped(_ task: TaskItem) {
    if sessionIsActive {
      pendingAction = .complete
    } else {
      let ref = task.id
      Task {
        if let provider = registry.closableProvider(for: ref) {
          await errorPresenter.attempt(AppLabels.Error.completeFailed) {
            try await provider.complete(ref)
          }
        }
        selectionStore.clearActiveTask()
      }
    }
  }

  // MARK: - Action dispatch

  private func commit(_ action: ActiveTaskConfirmAction, task: TaskItem) {
    switch action {
    case .complete:
      guard let provider = registry.closableProvider(for: task.id) else { return }
      let ref = task.id
      engine.stop()
      Task {
        await errorPresenter.attempt(AppLabels.Error.completeFailed) {
          try await provider.complete(ref)
        }
        selectionStore.clearActiveTask()
        if style == .detail { nav.showTasks() }
      }
    case .clear:
      engine.stop()
      selectionStore.clearActiveTask()
      if style == .detail { nav.showTasks() }
    }
  }
}

#Preview {
  let engine = SessionEngine()
  let registry = ProviderRegistry()
  let errorPresenter = ErrorPresenter()
  let settings = AppSettings()
  let nav = MainNavigation(
    settings: settings, selectionStore: SelectionStore(registry: registry),
    statsViewModel: .preview)

  @MainActor
  func store(priority: TaskPriority) -> TaskSelectionStore {
    let store = TaskSelectionStore()
    store.select(
      TaskItem(
        id: TaskRef(providerID: "adhoc", nativeID: UUID().uuidString),
        title: "Priority \(priority)",
        notes: "Some notes about the task.",
        format: .plainText,
        priority: priority,
        dueDate: nil,
        scheduledDate: nil,
        startDate: nil,
        list: nil,
        section: nil,
        sourceURL: nil,
        completedAt: nil,
        createdAt: Date()
      )
    )
    return store
  }

  let priorities: [TaskPriority] = [.highest, .high, .medium, .low, .lowest]

  return VStack(alignment: .leading, spacing: .sectionGap) {
    ForEach(priorities, id: \.self) { priority in
      ActiveTaskView(
        engine: engine, selectionStore: store(priority: priority), registry: registry,
        nav: nav, errorPresenter: errorPresenter, style: .compact, onSelect: {})
    }

    ForEach(priorities, id: \.self) { priority in
      ActiveTaskView(
        engine: engine, selectionStore: store(priority: priority), registry: registry,
        nav: nav, errorPresenter: errorPresenter, style: .detail, onSelect: nil)
    }
  }
  .padding()
  .frame(width: 360)
}
