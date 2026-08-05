//
//  LocalTaskEntity.swift
//  Taskmato
//

import Foundation
import SwiftData

/// The SwiftData persistence record mirroring a ``LocalTask``'s stored fields.
///
/// `format` and `priority` are stored directly as their enum values (the `SessionEntity`/
/// `SessionPhase` precedent). No `sortIndex` — task display order is always recomputed by
/// `TaskQueryService`'s sorter, never read from storage; `createdAt` alone is enough for a
/// deterministic fetch order.
@Model
final class LocalTaskEntity {

  /// Stable unique identifier and the record's identity.
  @Attribute(.unique) var id: UUID

  /// The task title shown in the picker and active-task label.
  var title: String

  /// Optional supplementary notes or description.
  var notes: String?

  /// How the task's `notes` string should be interpreted for display.
  var format: ContentFormat

  /// Priority level, used for sorting and badging in the picker.
  var priority: TaskPriority

  /// The date by which the task is due.
  var dueDate: Date?

  /// The date the task is scheduled to be worked on.
  var scheduledDate: Date?

  /// The earliest date the task should appear in the picker.
  var startDate: Date?

  /// The list this task belongs to, or `nil` if uncategorized.
  var listID: UUID?

  /// `true` when the task has been marked complete.
  var isCompleted: Bool

  /// Wall-clock time when the task was completed, or `nil` if still open.
  var completedAt: Date?

  /// Wall-clock time when the task was first created.
  var createdAt: Date

  /// Creates a persistence record from explicit field values.
  init(
    id: UUID, title: String, notes: String?, format: ContentFormat, priority: TaskPriority,
    dueDate: Date?, scheduledDate: Date?, startDate: Date?, listID: UUID?, isCompleted: Bool,
    completedAt: Date?, createdAt: Date
  ) {
    self.id = id
    self.title = title
    self.notes = notes
    self.format = format
    self.priority = priority
    self.dueDate = dueDate
    self.scheduledDate = scheduledDate
    self.startDate = startDate
    self.listID = listID
    self.isCompleted = isCompleted
    self.completedAt = completedAt
    self.createdAt = createdAt
  }
}

extension LocalTaskEntity {

  /// Creates a persistence record from a domain ``LocalTask``.
  convenience init(task: LocalTask) {
    self.init(
      id: task.id, title: task.title, notes: task.notes, format: task.format,
      priority: task.priority, dueDate: task.dueDate, scheduledDate: task.scheduledDate,
      startDate: task.startDate, listID: task.listID, isCompleted: task.isCompleted,
      completedAt: task.completedAt, createdAt: task.createdAt)
  }

  /// Updates this record's fields in place from a domain ``LocalTask``, keeping its identity —
  /// the mutate branch of ``SwiftDataLocalTaskRepository/save(_:)``.
  /// - Parameter task: The task to copy fields from.
  func update(from task: LocalTask) {
    title = task.title
    notes = task.notes
    format = task.format
    priority = task.priority
    dueDate = task.dueDate
    scheduledDate = task.scheduledDate
    startDate = task.startDate
    listID = task.listID
    isCompleted = task.isCompleted
    completedAt = task.completedAt
    createdAt = task.createdAt
  }
}

extension LocalTask {

  /// Reconstructs a domain ``LocalTask`` from its persistence record.
  nonisolated init(entity: LocalTaskEntity) {
    self.init(
      id: entity.id, title: entity.title, notes: entity.notes, format: entity.format,
      priority: entity.priority, dueDate: entity.dueDate, scheduledDate: entity.scheduledDate,
      startDate: entity.startDate, listID: entity.listID, isCompleted: entity.isCompleted,
      completedAt: entity.completedAt, createdAt: entity.createdAt)
  }
}
