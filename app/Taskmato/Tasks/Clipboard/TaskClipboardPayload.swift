//
//  TaskClipboardPayload.swift
//  Taskmato
//

import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// Versioned pasteboard envelope for a single copied or cut task (issue #546).
///
/// A dedicated, domain-layer wire format — not the raw ``TaskItem`` — so a future model
/// refactor can't silently break decoding of payloads written by an older build. Carries only
/// the fields the create form consumes; `scheduledDate`, `startDate`, `section`, and
/// `sourceURL` are intentionally dropped (no create-form field exists for them). `format` is
/// deliberately not stored: it is re-stamped from the paste destination's `contentFormat` on
/// import.
nonisolated struct TaskClipboardPayload: Codable, Sendable, Transferable {

  /// The envelope version this build writes and expects to read. A payload decoded with a
  /// different `version` is treated as unsupported by ``TaskClipboardService/canImport(_:)``.
  static let currentVersion = 1

  /// The envelope version this payload was encoded with.
  let version: Int

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
    self.version = Self.currentVersion
    self.title = title
    self.notes = notes
    self.priority = priority
    self.dueDate = dueDate
  }

  /// Captures the clipboard-relevant fields from `task`.
  init(from task: TaskItem) {
    self.init(title: task.title, notes: task.notes, priority: task.priority, dueDate: task.dueDate)
  }

  /// Prefers the rich, within-app `Codable` form; falls back to the plain-text title so pasting
  /// into another app yields the title and copying plain text elsewhere can be pasted back in.
  static var transferRepresentation: some TransferRepresentation {
    CodableRepresentation(contentType: .taskmatoTask)
    ProxyRepresentation(exporting: \.title)
  }
}

extension UTType {

  /// The exported Taskmato task type (`com.taskmato.task`, declared in Info.plist), backing
  /// ``TaskClipboardPayload``'s rich `Transferable` representation.
  ///
  /// `nonisolated` so ``TaskClipboardPayload/transferRepresentation`` (a nonisolated context)
  /// can reference it under the project's `-default-isolation=MainActor` setting.
  nonisolated static let taskmatoTask = UTType(exportedAs: "com.taskmato.task")
}
