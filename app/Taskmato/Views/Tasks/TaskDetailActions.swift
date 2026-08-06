//
//  TaskDetailActions.swift
//  Taskmato
//

import SwiftUI

// MARK: - Mutating action handlers

extension TaskDetailView {

  /// Marks `task` as completed via its closable provider.
  func handleComplete(_ task: TaskItem) {
    Task {
      if let provider = registry.closableProvider(for: task.id) {
        await errorPresenter.attempt(AppLabels.Error.completeFailed) {
          try await provider.complete(task.id)
        }
      }
      await refresh()
    }
  }

  /// Restores a previously completed `task` to its active list via its closable provider.
  func handleRestore(_ task: TaskItem) {
    Task {
      if let provider = registry.closableProvider(for: task.id) {
        await errorPresenter.attempt(AppLabels.Error.restoreFailed) {
          try await provider.reopen(task.id)
        }
      }
      await refresh()
    }
  }

  /// Permanently deletes `task` via its writable provider, clearing it as the active task only
  /// when the delete succeeds and it was the task currently being tracked.
  func handleDelete(_ task: TaskItem) {
    Task {
      var didDelete = false
      if let provider = registry.provider(for: task.id) as? (any WritableTaskProvider) {
        didDelete = await errorPresenter.attempt(AppLabels.Error.deleteFailed) {
          try await provider.deleteTask(task.id)
        }
      }
      if didDelete && selectionStore.activeTask?.id == task.id {
        selectionStore.clearActiveTask()
      }
      await loadCompleted()
    }
  }

  /// Copies `task` to the clipboard, then deletes it from its writable provider — the standard
  /// OS cut timing (copy first, then remove), accepted even though a failed delete can leave a
  /// duplicatable clipboard entry. Clears the active task only when the delete succeeds.
  func handleCut(_ task: TaskItem) {
    TaskClipboard.copy(task)
    Task {
      guard let provider = registry.writableProvider(for: task.id) else {
        await refresh()
        return
      }
      let didDelete = await errorPresenter.attempt(AppLabels.Error.deleteFailed) {
        try await provider.deleteTask(task.id)
      }
      if didDelete && selectionStore.activeTask?.id == task.id {
        selectionStore.clearActiveTask()
      }
      await refresh()
    }
  }

  /// Resolves the writable provider and destination list ID that ⌘V should target.
  ///
  /// `.today` targets the default writable provider's default list; a writable `.list`
  /// selection targets that provider and list; a read-only provider or no selection is a
  /// no-op (`nil`) rather than silently redirecting to another provider.
  func pasteDestination() -> (provider: any WritableTaskProvider, listID: String?)? {
    switch sidebarSelection.selection {
    case .today:
      guard
        let provider = registry.resolveDefaultWritableProvider(
          preferredID: settings.defaultWritableProviderID)
      else { return nil }
      return (provider, nil)
    case .list(let sel):
      guard
        let provider = registry.providers.first(where: {
          $0.id == sel.providerID && registry.isEnabled($0.id)
        }) as? (any WritableTaskProvider)
      else { return nil }
      return (provider, sel.listID)
    case nil:
      return nil
    }
  }

  /// Handles ⌘V / Edit ▸ Paste: reads the clipboard and adds a task to the resolved paste
  /// destination. No-ops gracefully when there is no writable destination or the clipboard
  /// holds neither a Taskmato payload nor plain text.
  func handlePaste() {
    guard let destination = pasteDestination() else { return }
    guard let payload = TaskClipboard.readPayload() else { return }
    Task {
      let draft = payload.makeDraft(
        listID: destination.listID, format: destination.provider.contentFormat)
      await errorPresenter.attempt(AppLabels.Error.addFailed) {
        try await destination.provider.addTask(draft)
      }
      await refresh()
    }
  }
}
