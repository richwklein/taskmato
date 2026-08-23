//
//  TaskDetailActions.swift
//  Taskmato
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

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

  /// Permanently deletes `task` via its writable provider. Clears it as the active task and/or
  /// the view's selection when the delete succeeds and either matched. Shared by the completed
  /// row's delete button, `.onDeleteCommand` on an active task (issue #546), and cut.
  func handleDelete(_ task: TaskItem) {
    Task {
      var didDelete = false
      if let provider = registry.provider(for: task.id) as? (any WritableTaskProvider) {
        didDelete = await errorPresenter.attempt(AppLabels.Error.deleteFailed) {
          try await provider.deleteTask(task.id)
        }
      }
      if didDelete {
        if activeTaskStore.activeTask?.id == task.id {
          activeTaskStore.clearActiveTask()
        }
        if selectedTaskID == task.id {
          selectedTaskID = nil
        }
      }
      await refresh()
    }
  }

  /// Writes `task` to `pasteboard` as both the rich Taskmato payload and a plain-text title
  /// fallback (issue #546). Backs the right-click Copy/Cut menu items, which sit outside
  /// SwiftUI's automatic `.copyable`/`.cuttable` Edit-menu wiring and so write the pasteboard
  /// manually rather than through a `Transferable` return value.
  /// - Parameters:
  ///   - task: The task to copy.
  ///   - pasteboard: The pasteboard to write to; defaults to the system general pasteboard.
  func copyToPasteboard(_ task: TaskItem, to pasteboard: NSPasteboard = .general) {
    pasteboard.clearContents()
    let payload = clipboardService.payload(for: task)
    if let data = try? JSONEncoder().encode(payload) {
      pasteboard.setData(data, forType: NSPasteboard.PasteboardType(UTType.taskmatoTask.identifier))
    }
    pasteboard.setString(task.title, forType: .string)
  }

  /// Handles the right-click Cut menu item: writes `task` to the pasteboard, then deletes it —
  /// the manual equivalent of the automatic `.cuttable` Edit-menu/⌘X path (which returns its
  /// payload for SwiftUI to write instead of calling ``copyToPasteboard(_:to:)``).
  func handleCut(_ task: TaskItem) {
    copyToPasteboard(task)
    handleDelete(task)
  }
}
