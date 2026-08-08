//
//  TaskDetailSelection.swift
//  Taskmato
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Selection, keyboard, and clipboard wiring

/// Selection-driven behavior for `TaskDetailView` (issue #546): resolving `selection` to a
/// task, Return/Delete key handling, and attaching the `Transferable`-backed copy/cut/paste
/// modifiers. Split from `TaskDetailView.swift` to keep that file under the repo's file-length
/// limit, mirroring the existing `TaskDetailActions.swift` split for mutating handlers.
extension TaskDetailView {

  /// Requests task-content focus through the invisible AppKit responder.
  func focusTaskContent() {
    taskContentFocusToken += 1
  }

  /// Returns the active or inactive selection fill for `task`.
  func selectionBackground(for task: TaskItem) -> Color {
    guard selection == task.id else { return .clear }
    return isTaskContentFocused ? .activeSelection : .inactiveSelection
  }

  /// The task currently identified by ``selection`` within active or completed tasks, or `nil`
  /// when there is no selection or the selected ref fell out of the loaded content.
  private func selectedTask() -> TaskItem? {
    guard let selection else { return nil }
    return sections.lazy.flatMap(\.tasks).first { $0.id == selection }
      ?? completedTasks.first { $0.id == selection }
  }

  /// The active task currently identified by ``selection``, or `nil` when the selected task is
  /// completed or no longer loaded.
  private func selectedActiveTask() -> TaskItem? {
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

  /// Moves ``selection`` to the previous/next selectable task in display order. Clamps at the
  /// ends; with no selection, next selects the first task and previous selects the last.
  func moveSelection(_ direction: MoveCommandDirection) {
    let ids =
      sections.flatMap(\.tasks).map(\.id)
      + (showCompleted ? completedTasks.map(\.id) : [])
    guard !ids.isEmpty else { return }
    let current = selection.flatMap { ids.firstIndex(of: $0) }
    switch direction {
    case .left, .up:
      selection = current.map { ids[max(0, $0 - 1)] } ?? ids.last
    case .right, .down:
      selection = current.map { ids[min(ids.count - 1, $0 + 1)] } ?? ids.first
    default:
      break
    }
  }

  /// Activates an active ``selection`` (mirrors double-click), or ignores the key when nothing
  /// active is selected so Return keeps its default behavior elsewhere.
  func activateSelection() -> KeyPress.Result {
    guard let task = selectedActiveTask() else { return .ignored }
    select(task)
    return .handled
  }

  /// Requests confirmation to permanently delete ``selection``, or beeps when it is not writable.
  /// No-ops silently when there is no selection.
  func requestDeleteSelection() {
    guard let task = selectedTask() else { return }
    guard clipboardService.canDelete(isWritable: registry.writableProvider(for: task.id) != nil)
    else {
      NSSound.beep()
      return
    }
    activeDeleteCandidate = task
  }

  /// Whether the current selection can be copied.
  func canCopySelection() -> Bool {
    selectedTask() != nil
  }

  /// Whether the current selection can be cut.
  func canCutSelection() -> Bool {
    guard let task = selectedTask() else { return false }
    return clipboardService.canCut(isWritable: registry.writableProvider(for: task.id) != nil)
  }

  /// Whether the current selection can be deleted.
  func canDeleteSelection() -> Bool {
    guard let task = selectedTask() else { return false }
    return clipboardService.canDelete(isWritable: registry.writableProvider(for: task.id) != nil)
  }

  /// Whether the current pasteboard content can be pasted into this task scope.
  func canPasteSelection(from pasteboard: NSPasteboard = .general) -> Bool {
    guard pasteProvider != nil else { return false }
    let taskType = NSPasteboard.PasteboardType(UTType.taskmatoTask.identifier)
    if pasteboard.data(forType: taskType) != nil {
      return true
    }
    return pasteboard.string(forType: .string)?.isEmpty == false
  }

  /// Copies the current selection to the pasteboard.
  func copySelectionToPasteboard() {
    guard let task = selectedTask() else { return }
    copyToPasteboard(task)
  }

  /// Cuts the current selection to the pasteboard.
  func cutSelectionToPasteboard() {
    guard let task = selectedTask(), canCutSelection() else { return }
    handleCut(task)
  }

  /// Pastes the current pasteboard into this task scope using the same strict paste target as
  /// `.pasteDestination`.
  func pasteSelectionFromPasteboard(_ pasteboard: NSPasteboard = .general) {
    guard
      let target = clipboardService.pasteTarget(
        for: pasteProvider, listID: selectedListIDForPaste)
    else { return }
    let taskType = NSPasteboard.PasteboardType(UTType.taskmatoTask.identifier)
    if let data = pasteboard.data(forType: taskType) {
      if let payload = try? JSONDecoder().decode(TaskClipboardPayload.self, from: data) {
        handlePastePayloads([payload], target: target)
      }
    } else if let text = pasteboard.string(forType: .string) {
      handlePasteTexts([text], target: target)
    }
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

  /// Returns the writable provider that paste should target without redirecting a read-only list
  /// selection to the default local provider.
  var pasteProvider: (any WritableTaskProvider)? {
    guard case .list(let sel) = sidebarSelection.selection else {
      return registry.resolveDefaultWritableProvider(
        preferredID: settings.defaultWritableProviderID)
    }
    return registry.enabledWritableProvider(id: sel.providerID)
  }

  /// The selected list ID to use for paste, only when that list belongs to ``pasteProvider``.
  var selectedListIDForPaste: String? {
    guard let provider = pasteProvider else { return nil }
    return sidebarSelection.selection?.listID(matching: provider.id)
  }

  /// Attaches the shared selected-task delete confirmation dialog to `content`.
  @ViewBuilder
  func attachActiveDeleteConfirmation<Content: View>(to content: Content) -> some View {
    content
      .confirmationDialog(
        "Delete this task permanently?", isPresented: activeDeleteConfirmationBinding
      ) {
        Button("Delete", role: .destructive) { confirmDeleteSelection() }
        Button("Cancel", role: .cancel) {}
      }
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
      for: pasteProvider, listID: selectedListIDForPaste)
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

  /// Attaches the invisible task-content keyboard responder to `content`.
  func attachTaskKeyboardResponder<Content: View>(to content: Content) -> some View {
    content.overlay(alignment: .topLeading) {
      TaskKeyboardResponder(
        focusToken: taskContentFocusToken,
        onReturn: { _ = activateSelection() },
        onDelete: { requestDeleteSelection() },
        onMove: { moveSelection($0) },
        onCopy: { copySelectionToPasteboard() },
        onCut: { cutSelectionToPasteboard() },
        onPaste: { pasteSelectionFromPasteboard() },
        canCopy: { canCopySelection() },
        canCut: { canCutSelection() },
        canPaste: { canPasteSelection() },
        canDelete: { canDeleteSelection() },
        onFocusChange: { isTaskContentFocused = $0 }
      )
      .frame(width: 0, height: 0)
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
