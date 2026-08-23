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
/// Hidden when no task is selected and nothing is staged. Completing, swapping, or clearing
/// mid-session pauses the live focus phase, closes and credits the outgoing slice, and — on
/// ``ActiveTaskStyle/detail`` — routes to the task picker (D2/D3 of design doc 0010); no
/// confirmation is shown, since the action is no longer destructive. During a break the same
/// three actions only mutate the selection, with no pause, slice, or routing (D10). A staged
/// task (design doc "stage the next focus") is always dropped by swap or clear, and promoted
/// directly — skipping the picker — by complete (D-e/D-f). At ``ActiveTaskStyle/detail``, a
/// staged task's title renders as a "Next:" line (D-d) — even with no active task at all, since
/// swap/clear can leave the active slot empty while a staged plan survives. The same view backs
/// the popover, the in-window strip, and the Timer destination; ``style`` drives which
/// affordances render and whether completing/swapping/clearing navigates the window.
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
  /// Supplies the staged "next focus" task for the `.detail` "Next:" line. `nil` on `.compact`
  /// surfaces (the popover, the in-window strip), which never show next-up (D-d).
  var nextUp: NextUpPresenter?
  /// Invoked when the user clicks the title; `nil` renders the title as plain, non-interactive text.
  var onSelect: (() -> Void)?

  @State private var isCompletionHovered: Bool = false

  private var sessionIsActive: Bool { engine.state != .idle }

  /// The phase currently running or paused, or `nil` while idle.
  private var currentPhase: SessionPhase? {
    switch engine.state {
    case .running(let phase, _, _): return phase
    case .paused(let phase, _): return phase
    case .idle: return nil
    }
  }

  /// `true` while a session is active and the current phase is a break — complete/swap/clear
  /// only mutate the selection during a break, never pausing, slicing, or routing (D10).
  private var isBreakPhase: Bool {
    currentPhase == .shortBreak || currentPhase == .longBreak
  }

  var body: some View {
    if let task = selectionStore.activeTask {
      taskRow(for: task)
    } else if style == .detail, let staged = nextUp?.stagedTask {
      nextUpLine(for: staged)
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
            swapTapped()
          } label: {
            Image(systemName: "arrow.triangle.swap")
              .foregroundStyle(.secondary)
          }
          .buttonStyle(.plain)
          .help(AppLabels.Tooltip.swapTask)
          .accessibilityLabel(AppLabels.Tooltip.swapTask)
        }

        Button {
          clearTapped()
        } label: {
          Image(systemName: "xmark")
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help(AppLabels.Tooltip.clearTask)
        .accessibilityLabel(AppLabels.Tooltip.clearTask)
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

          if let staged = nextUp?.stagedTask {
            nextUpLine(for: staged)
          }
        }
      }
    }
  }

  /// The "Next: <title>" line shown at `.detail` while a task is staged (design doc "stage the
  /// next focus", D-d) — pairs with ``NextUpReadout``'s length line on the ring.
  private func nextUpLine(for task: TaskItem) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: .iconLabel) {
      Text(AppLabels.NextUp.taskPrefix)
        .font(.caption)
        .foregroundStyle(.secondary)
      TaskMarkdownTitle(task: task, lineLimit: 1, font: .caption)
    }
  }

  // MARK: - Leading indicator

  /// Returns a completion button when the provider supports mutation, or nothing otherwise.
  @ViewBuilder
  private func leadingIndicator(for task: TaskItem) -> some View {
    if registry.closableProvider(for: task.id) != nil {
      TaskCompletionButton(
        action: { completeTapped(task) },
        label: (sessionIsActive && !isBreakPhase)
          ? AppLabels.Tooltip.markAsCompletedActive : AppLabels.Tooltip.markAsCompleted,
        isHovered: $isCompletionHovered
      )
    }
  }

  // MARK: - Action dispatch

  /// Handles a tap on the completion circle.
  ///
  /// During a live focus phase, pauses first so provider-call latency doesn't leak into the
  /// outgoing slice's credited time (D3 of design doc 0010); on success a staged task promotes
  /// directly — there is nothing left to pick — otherwise the slice closes
  /// (`clearActiveTask()`) and the surface routes to Tasks; on failure the phase resumes and
  /// the error surfaces. While idle or mid-break, only mutates the selection — no pause,
  /// slice, or routing (D10) — but a staged task still promotes directly rather than just
  /// clearing (D-f, "stage the next focus"). Not `private`, so tests can exercise the D-e/D-f
  /// gesture matrix without rendering the view.
  func completeTapped(_ task: TaskItem) {
    guard let provider = registry.closableProvider(for: task.id) else { return }
    let ref = task.id
    guard sessionIsActive, !isBreakPhase else {
      Task {
        let succeeded = await errorPresenter.attempt(AppLabels.Error.completeFailed) {
          try await provider.complete(ref)
        }
        guard succeeded else { return }
        if selectionStore.stagedTask != nil {
          selectionStore.promoteStaged()
        } else {
          selectionStore.clearActiveTask()
        }
      }
      return
    }
    engine.pause()
    Task {
      do {
        try await provider.complete(ref)
        if selectionStore.stagedTask != nil {
          selectionStore.promoteStaged()
        } else {
          selectionStore.clearActiveTask()
          selectionStore.markPendingContinuation()
          if style == .detail { nav.showTasks() }
        }
      } catch {
        engine.resume()
        errorPresenter.present(title: AppLabels.Error.completeFailed, error: error)
      }
    }
  }

  /// Pauses the live focus phase and routes to the task picker so the user can choose a
  /// replacement; the outgoing slice closes once that selection lands (D2). During a break the
  /// phase keeps running untouched — only the routing happens (D10). Always drops a staged task
  /// (D-e, "stage the next focus") — swapping the active task makes an earlier plan moot. Not
  /// `private`, so tests can exercise the D-e/D-f gesture matrix without rendering the view.
  func swapTapped() {
    selectionStore.clearStagedTask()
    if !isBreakPhase {
      engine.pause()
      selectionStore.markPendingContinuation()
    }
    nav.openMainWindow()
    nav.showTasks()
  }

  /// Pauses, closes the outgoing slice, and detaches the active task. While idle or mid-break,
  /// only detaches — no pause, slice, or routing (D10). `clearActiveTask()` also drops a staged
  /// task (D-e, "stage the next focus"). Not `private`, so tests can exercise the D-e/D-f
  /// gesture matrix without rendering the view.
  func clearTapped() {
    guard sessionIsActive, !isBreakPhase else {
      selectionStore.clearActiveTask()
      return
    }
    engine.pause()
    selectionStore.clearActiveTask()
    selectionStore.markPendingContinuation()
    if style == .detail { nav.showTasks() }
  }
}

#if DEBUG
  #Preview {
    let engine = SessionEngine()
    let registry = ProviderRegistry()
    let errorPresenter = ErrorPresenter()
    let settings = AppSettings()
    let nav = MainNavigation(
      settings: settings, selectionStore: SelectionStore(registry: registry),
      statsViewModel: .preview)

    @MainActor
    func task(title: String, priority: TaskPriority) -> TaskItem {
      TaskItem(
        id: TaskRef(providerID: "adhoc", nativeID: UUID().uuidString),
        title: title,
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
    }

    @MainActor
    func store(priority: TaskPriority) -> TaskSelectionStore {
      let store = TaskSelectionStore()
      store.select(task(title: "Priority \(priority)", priority: priority))
      return store
    }

    @MainActor
    func nextUpPresenter(for store: TaskSelectionStore) -> NextUpPresenter {
      NextUpPresenter(
        presenter: TimerPresenter(engine: engine, settings: settings), selectionStore: store,
        settings: settings)
    }

    let priorities: [TaskPriority] = [.highest, .high, .medium, .low, .lowest]

    let stagedActiveStore = store(priority: .high)
    stagedActiveStore.stage(task(title: "Staged next focus task", priority: .medium))

    let stagedOnlyStore = TaskSelectionStore()
    stagedOnlyStore.stage(task(title: "Staged with no active task", priority: .low))

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

      ActiveTaskView(
        engine: engine, selectionStore: stagedActiveStore, registry: registry, nav: nav,
        errorPresenter: errorPresenter, style: .detail,
        nextUp: nextUpPresenter(for: stagedActiveStore), onSelect: nil)

      ActiveTaskView(
        engine: engine, selectionStore: stagedOnlyStore, registry: registry, nav: nav,
        errorPresenter: errorPresenter, style: .detail,
        nextUp: nextUpPresenter(for: stagedOnlyStore), onSelect: nil)
    }
    .padding()
    .frame(width: 360)
  }
#endif
