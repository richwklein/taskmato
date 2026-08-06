//
//  TaskClipboard.swift
//  Taskmato
//

import AppKit
import Foundation

/// The clipboard representation of a copied or cut ``TaskItem`` (issue #422).
///
/// Carries only the fields the create form consumes. `scheduledDate`, `startDate`, `section`,
/// and `sourceURL` are intentionally dropped — no create-form field exists for them.
struct TaskClipboardPayload: Codable, Sendable {

  /// The task title.
  let title: String

  /// Optional notes, or `nil` if the source task had none.
  let notes: String?

  /// Priority level.
  let priority: TaskPriority

  /// Due date, or `nil` if unset.
  let dueDate: Date?

  /// Creates a payload directly from its fields, e.g. a title-only fallback from plain text.
  init(title: String, notes: String?, priority: TaskPriority, dueDate: Date?) {
    self.title = title
    self.notes = notes
    self.priority = priority
    self.dueDate = dueDate
  }

  /// Captures the four clipboard-relevant fields from `task`.
  init(from task: TaskItem) {
    self.init(title: task.title, notes: task.notes, priority: task.priority, dueDate: task.dueDate)
  }

  /// Maps this payload to a ``TaskDraft`` targeting `listID`, stamped with the destination
  /// provider's `format`.
  /// - Parameters:
  ///   - listID: The destination provider-local list ID, or `nil` for the provider's default list.
  ///   - format: The destination provider's `contentFormat`.
  func makeDraft(listID: String?, format: ContentFormat) -> TaskDraft {
    TaskDraft(
      title: title,
      notes: notes ?? "",
      format: format,
      priority: priority,
      dueDate: dueDate,
      listID: listID
    )
  }
}

/// Reads and writes tasks to the system pasteboard for cut/copy/paste (issue #422).
///
/// Every write includes both the private ``pasteboardType`` JSON representation (the full
/// payload) and a plain-text `.string` fallback (the title only), so a Taskmato task pastes
/// cleanly into other apps and plain text copied elsewhere can be pasted in as a title-only task.
enum TaskClipboard {

  /// The private pasteboard type carrying a full ``TaskClipboardPayload`` as JSON.
  ///
  /// An arbitrary same-app string, not a declared `UTType` — no Info.plist entry is needed.
  static let pasteboardType = NSPasteboard.PasteboardType("com.taskmato.task")

  /// Writes `task` to `pasteboard` as both the private payload type and a plain-text title.
  /// - Parameters:
  ///   - task: The task to copy.
  ///   - pasteboard: The pasteboard to write to; defaults to the system general pasteboard.
  static func copy(_ task: TaskItem, to pasteboard: NSPasteboard = .general) {
    pasteboard.clearContents()
    let payload = TaskClipboardPayload(from: task)
    if let data = try? JSONEncoder().encode(payload) {
      pasteboard.setData(data, forType: pasteboardType)
    }
    pasteboard.setString(task.title, forType: .string)
  }

  /// Reads a task payload from `pasteboard`, preferring the rich ``pasteboardType`` and
  /// falling back to a title-only payload built from `.string`.
  /// - Parameter pasteboard: The pasteboard to read from; defaults to the system general pasteboard.
  /// - Returns: The decoded payload, or `nil` if the pasteboard holds neither a recognizable
  ///   Taskmato payload nor non-empty plain text.
  static func readPayload(from pasteboard: NSPasteboard = .general) -> TaskClipboardPayload? {
    if let data = pasteboard.data(forType: pasteboardType) {
      if let payload = try? JSONDecoder().decode(TaskClipboardPayload.self, from: data) {
        return payload
      }
    }
    if let title = pasteboard.string(forType: .string), !title.isEmpty {
      return TaskClipboardPayload(title: title, notes: nil, priority: .none, dueDate: nil)
    }
    return nil
  }
}
