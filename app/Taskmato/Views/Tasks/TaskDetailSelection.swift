//
//  TaskDetailSelection.swift
//  Taskmato
//

import AppKit
import SwiftUI

// MARK: - Selection, keyboard, and clipboard wiring

/// Selection-driven behavior for `TaskDetailView` (issue #546): resolving `selection` to a
/// task, Return/Delete key handling, and attaching the `Transferable`-backed copy/cut/paste
/// modifiers. Split from `TaskDetailView.swift` to keep that file under the repo's file-length
/// limit, mirroring the existing `TaskDetailActions.swift` split for mutating handlers.
extension TaskDetailView {

  /// The task currently identified by ``selection`` within the loaded active sections, or
  /// `nil` when there is no selection or the selected ref fell out of `sections` (e.g. a
  /// background refresh removed it).
  private func selectedTask() -> TaskItem? {
    guard let selection else { return nil }
    return sections.lazy.flatMap(\.tasks).first { $0.id == selection }
  }

  /// The payload for ``selection``, or an empty array when there is nothing selected —
  /// SwiftUI disables Edit ▸ Copy when `.copyable` returns no items.
  private func copyPayloads() -> [TaskClipboardPayload] {
    guard let task = selectedTask() else { return [] }
    return [clipboardService.payload(for: task)]
  }

  /// Deletes ``selection`` and returns its payload for `.cuttable` to place on the pasteboard,
  /// or an empty array when there is nothing selected or it is not writable.
  private func cutPayloads() -> [TaskClipboardPayload] {
    guard let task = selectedTask(),
      clipboardService.canCut(isWritable: registry.writableProvider(for: task.id) != nil)
    else { return [] }
    handleDelete(task)
    return [clipboardService.payload(for: task)]
  }

  /// `.onMoveCommand`: moves ``selection`` to the previous/next active task in display order for
  /// the grid's **Left/Right** arrow keys. Up/Down are intentionally unhandled — vertical grid
  /// navigation needs runtime column geometry and is deferred (issue #546, D10); the list gets
  /// full arrow navigation natively from `NSTableView`. Clamps at the ends; with no selection,
  /// Right selects the first task and Left the last.
  func moveGridSelection(_ direction: MoveCommandDirection) {
    let ids = sections.flatMap(\.tasks).map(\.id)
    guard !ids.isEmpty else { return }
    let current = selection.flatMap { ids.firstIndex(of: $0) }
    switch direction {
    case .left:
      selection = current.map { ids[max(0, $0 - 1)] } ?? ids.last
    case .right:
      selection = current.map { ids[min(ids.count - 1, $0 + 1)] } ?? ids.first
    default:
      break
    }
  }

  /// `.onKeyPress(.return)`: activates ``selection`` (mirrors double-click), or ignores the key
  /// when nothing is selected so Return keeps its default behavior elsewhere.
  func activateSelection() -> KeyPress.Result {
    guard let task = selectedTask() else { return .ignored }
    select(task)
    return .handled
  }

  /// `.onDeleteCommand`: requests confirmation to permanently delete ``selection``, or beeps
  /// when it is not writable. No-ops silently when there is no selection.
  func requestDeleteSelection() {
    guard let task = selectedTask() else { return }
    guard clipboardService.canDelete(isWritable: registry.writableProvider(for: task.id) != nil)
    else {
      NSSound.beep()
      return
    }
    activeDeleteCandidate = task
  }

  /// Confirms the pending deletion from ``requestDeleteSelection()``.
  func confirmDeleteSelection() {
    guard let task = activeDeleteCandidate else { return }
    activeDeleteCandidate = nil
    handleDelete(task)
  }

  /// Drives the active-delete confirmation dialog from ``activeDeleteCandidate``.
  var activeDeleteConfirmationBinding: Binding<Bool> {
    Binding(
      get: { activeDeleteCandidate != nil },
      set: { isPresented in if !isPresented { activeDeleteCandidate = nil } }
    )
  }

  /// Attaches copy/cut, and — only when a writable paste target exists (D5) — paste, to
  /// `content`. Shared by both layouts so list and grid get identical Edit-menu behavior.
  @ViewBuilder
  func attachClipboardModifiers<Content: View>(to content: Content) -> some View {
    let withCopyAndCut =
      content
      .copyable(copyPayloads())
      .cuttable(for: TaskClipboardPayload.self, action: cutPayloads)
    let target = clipboardService.pasteTarget(
      for: writableProvider, listID: selectedListIDForNewTask)
    if let target {
      withCopyAndCut
        .pasteDestination(for: TaskClipboardPayload.self) { payloads in
          handlePastePayloads(payloads, target: target)
        }
        .pasteDestination(for: String.self) { texts in
          handlePasteTexts(texts, target: target)
        }
    } else {
      withCopyAndCut
    }
  }

  /// Handles an inbound rich Taskmato payload from `.pasteDestination(for: TaskClipboardPayload.self)`.
  private func handlePastePayloads(_ payloads: [TaskClipboardPayload], target: TaskPasteTarget) {
    guard let payload = payloads.first, clipboardService.canImport(payload) else { return }
    let draft = clipboardService.draft(
      from: payload, listID: target.listID, format: target.provider.contentFormat,
      dueToday: sidebarSelection.selection == .today)
    performPaste(draft, provider: target.provider)
  }

  /// Handles inbound plain text from `.pasteDestination(for: String.self)` (e.g. pasted from
  /// another app).
  private func handlePasteTexts(_ texts: [String], target: TaskPasteTarget) {
    guard let text = texts.first, !text.isEmpty else { return }
    let draft = clipboardService.draft(
      fromPlainText: text, listID: target.listID, format: target.provider.contentFormat,
      dueToday: sidebarSelection.selection == .today)
    performPaste(draft, provider: target.provider)
  }

  /// Creates `draft` in `provider`, then refreshes.
  private func performPaste(_ draft: TaskDraft, provider: any WritableTaskProvider) {
    Task {
      await errorPresenter.attempt(AppLabels.Error.addFailed) {
        try await provider.addTask(draft)
      }
      await refresh()
    }
  }
}
