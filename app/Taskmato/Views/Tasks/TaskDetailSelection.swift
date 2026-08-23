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

  /// Tracks an active ``selection``, or ignores the key when nothing active is selected so
  /// Return keeps its default behavior elsewhere.
  func activateSelection() -> KeyPress.Result {
    guard let task = selectedActiveTask() else { return .ignored }
    select(task)
    return .handled
  }

  /// The action that tracks the current selection and switches to Timer, or `nil` when no
  /// active task is selected. Feeds the toolbar button and the Task ▸ Track Task menu item —
  /// the pointer-driven counterparts to Return, which activates the same way.
  func trackSelectionAction() -> (() -> Void)? {
    guard let task = selectedActiveTask() else { return nil }
    return { select(task) }
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

  /// The provider deep link for the current selection, or `nil` when there is no selection or
  /// it has nothing to open (Local and ad-hoc tasks).
  func selectedProviderLink() -> TaskProviderLink? {
    guard let task = selectedTask() else { return nil }
    return TaskProviderLink(task: task, registry: registry)
  }

  /// Opens `task`'s provider deep link, or no-ops when it has none.
  func openInProvider(_ task: TaskItem) {
    guard let link = TaskProviderLink(task: task, registry: registry) else { return }
    openURL(link.url)
  }

  /// The action that opens the current selection's provider link, or `nil` when there is
  /// nothing to open. Gates on the resolved link, not merely on a selection, so the command
  /// stays disabled for Local and ad-hoc tasks rather than offering an action that no-ops.
  /// Feeds the `\.openInProvider` focused-scene value; split out to a standalone method —
  /// rather than an inline closure in `TaskDetailView.body` — so the type-checker doesn't have
  /// to infer through a nested optional-closure expression there.
  func openInProviderAction() -> (() -> Void)? {
    guard let link = selectedProviderLink() else { return nil }
    return { openURL(link.url) }
  }

  /// Attaches the Open in Provider focused-scene values to `content`. Kept out of `body`'s own
  /// modifier chain — which already publishes six other focused-scene values — so the Swift
  /// type-checker isn't asked to solve one over-long chained expression (mirrors why
  /// ``trackedDetail`` was already split out of `body`).
  @ViewBuilder
  func attachOpenInProviderFocusedValues<Content: View>(to content: Content) -> some View {
    content
      .focusedSceneValue(\.trackTask, trackSelectionAction())
      .focusedSceneValue(\.openInProvider, openInProviderAction())
      .focusedSceneValue(\.openInProviderTitle, selectedProviderLink()?.title)
      .focusedSceneValue(\.openInProviderIcon, selectedProviderLink()?.icon)
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
    guard case .list = sidebarSelection.selection else {
      return destinationResolver.provider()
    }
    return destinationResolver.provider(sidebarSelection: sidebarSelection.selection)
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

  /// Attaches Return-to-track and Delete to `content`, leaving the `List` as first responder.
  ///
  /// Arrow-key movement is not handled here — `List(selection:)` moves the selection natively.
  @ViewBuilder
  func attachTaskCommands<Content: View>(to content: Content) -> some View {
    content
      .onKeyPress(.return) { activateSelection() }
      .onDeleteCommand { requestDeleteSelection() }
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
        let destination = try await destinationResolver.resolve(
          providerID: provider.id, listID: draft.listID)
        var routedDraft = draft
        routedDraft.listID = destination.listID
        try await destination.provider.addTask(routedDraft)
      }
      await refresh()
    }
  }
}
