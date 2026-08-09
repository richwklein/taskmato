//
//  TaskClipboardService.swift
//  Taskmato
//

import Foundation

/// A resolved paste destination: the writable provider a pasted task should be created in, and
/// which of its lists.
nonisolated struct TaskPasteTarget {

  /// The writable provider that will receive the pasted task.
  let provider: any WritableTaskProvider

  /// The provider-local list ID to target, or `nil` for the provider's default list.
  let listID: String?
}

/// Maps between ``TaskItem``/``TaskClipboardPayload``/plain text and ``TaskDraft``, and answers
/// the cut/delete/paste enablement questions for task selection (issue #546).
///
/// Stateless and domain-layer only — no SwiftUI import, per the engine/service separation rule.
/// Writability and paste-target resolution are passed in by the caller rather than resolved
/// from ``ProviderRegistry`` here, so every method is a pure function that unit-tests without a
/// `@MainActor` registry.
nonisolated struct TaskClipboardService: Sendable {

  /// Builds the clipboard payload for a copied or cut task.
  /// - Parameter task: The task to capture.
  func payload(for task: TaskItem) -> TaskClipboardPayload {
    TaskClipboardPayload(from: task)
  }

  /// Whether `payload`'s envelope version is one this build supports importing.
  /// - Parameter payload: The payload read from the pasteboard.
  func canImport(_ payload: TaskClipboardPayload) -> Bool {
    payload.version == TaskClipboardPayload.currentVersion
  }

  /// Maps a pasted-in payload to a draft for `listID`, re-stamping `format` from the
  /// destination provider. The pasted task is always active; `scheduledDate`, `startDate`,
  /// `section`, and `sourceURL` are dropped — not expressible via ``TaskDraft``.
  /// - Parameters:
  ///   - payload: The decoded clipboard payload. Callers should check ``canImport(_:)`` first.
  ///   - listID: The destination provider-local list ID, or `nil` for the provider's default list.
  ///   - format: The destination provider's `contentFormat`.
  ///   - dueToday: When `true` (pasting under Today), overwrites the due date with the start of
  ///     today so the pasted task appears in the Today view; otherwise the payload's due date is
  ///     carried through.
  func draft(
    from payload: TaskClipboardPayload, listID: String?, format: ContentFormat,
    dueToday: Bool = false
  ) -> TaskDraft {
    TaskDraft(
      title: payload.title,
      notes: payload.notes ?? "",
      format: format,
      priority: payload.priority,
      dueDate: dueToday ? Calendar.current.startOfDay(for: .now) : payload.dueDate,
      listID: listID
    )
  }

  /// Maps inbound plain text (e.g. pasted from another app) to a title-only draft.
  /// - Parameters:
  ///   - title: The plain text read from the pasteboard.
  ///   - listID: The destination provider-local list ID, or `nil` for the provider's default list.
  ///   - format: The destination provider's `contentFormat`.
  ///   - dueToday: When `true` (pasting under Today), sets the due date to the start of today so
  ///     the pasted task appears in the Today view.
  func draft(
    fromPlainText title: String, listID: String?, format: ContentFormat, dueToday: Bool = false
  ) -> TaskDraft {
    TaskDraft(
      title: title, notes: "", format: format, priority: .none,
      dueDate: dueToday ? Calendar.current.startOfDay(for: .now) : nil, listID: listID)
  }

  /// Whether the selected task can be cut. Cut copies then immediately deletes, so it requires
  /// the same writability as delete.
  /// - Parameter isWritable: Whether the selected task's provider is writable.
  func canCut(isWritable: Bool) -> Bool { isWritable }

  /// Whether the selected active task can be permanently deleted via `.onDeleteCommand`.
  /// - Parameter isWritable: Whether the selected task's provider is writable.
  func canDelete(isWritable: Bool) -> Bool { isWritable }

  /// Whether paste is available for the given resolved target.
  /// - Parameter target: The target resolved by ``pasteTarget(for:listID:)``.
  func canPaste(target: TaskPasteTarget?) -> Bool { target != nil }

  /// Packages an already-resolved writable provider and list ID as a ``TaskPasteTarget``.
  ///
  /// Callers resolve `provider`/`listID` the same way "+ New Task" does — the current sidebar
  /// selection's writable provider, falling back to the default writable provider — so paste
  /// always lands where the toolbar's add-task button would.
  /// - Parameters:
  ///   - provider: The writable provider for the current sidebar selection, or `nil` when none
  ///     is available.
  ///   - listID: The list ID to target within `provider`.
  /// - Returns: `nil` when there is no writable provider to target.
  func pasteTarget(for provider: (any WritableTaskProvider)?, listID: String?) -> TaskPasteTarget? {
    guard let provider else { return nil }
    return TaskPasteTarget(provider: provider, listID: listID)
  }
}
