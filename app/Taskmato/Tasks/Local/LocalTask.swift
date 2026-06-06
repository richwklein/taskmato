//
//  LocalTask.swift
//  Taskmato
//

import Foundation

/// A single task stored in the local JSON task store.
///
/// Extends the core ``TaskItem`` properties with completion state. The ``asTaskItem(lists:)``
/// method converts to the provider-agnostic representation used by the picker and session log.
struct LocalTask: Codable, Identifiable {

  /// Stable unique identifier for this task.
  let id: UUID

  /// The task title shown in the picker and active-task label.
  var title: String

  /// Optional supplementary notes or description.
  var notes: String?

  /// How the task's `notes` string should be interpreted for display.
  ///
  /// Defaults to `.markdown` for all new tasks. Existing JSON records without this
  /// field also decode as `.markdown` via ``init(from:)``.
  var format: NoteFormat

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

  /// `true` when the task has been marked complete via ``LocalProvider/complete(_:)``.
  var isCompleted: Bool

  /// Wall-clock time when the task was completed, or `nil` if still open.
  var completedAt: Date?

  /// Wall-clock time when the task was first created.
  let createdAt: Date

  private enum CodingKeys: String, CodingKey {
    case id, title, notes, format, priority, dueDate, scheduledDate, startDate
    case listID, isCompleted, completedAt, createdAt
  }

  /// Converts this task to the provider-agnostic ``TaskItem`` used by the picker and registry.
  ///
  /// - Parameter lists: The full list of ``LocalList`` values managed by the provider,
  ///   used to resolve `listID` into a display name.
  func asTaskItem(lists: [LocalList]) -> TaskItem {
    let taskList =
      listID
      .flatMap { lid in lists.first { $0.id == lid } }
      .map { TaskList(id: $0.id.uuidString, providerID: LocalProvider.providerID, name: $0.name) }
    return TaskItem(
      id: TaskRef(providerID: LocalProvider.providerID, nativeID: id.uuidString),
      title: title,
      notes: notes,
      format: format,
      priority: priority,
      dueDate: dueDate,
      scheduledDate: scheduledDate,
      startDate: startDate,
      list: taskList,
      completedAt: completedAt,
      createdAt: createdAt
    )
  }

  /// Applies the editable fields of `draft` to this task in place.
  mutating func apply(_ draft: TaskDraft) {
    title = draft.title
    notes = draft.notes.isEmpty ? nil : draft.notes
    priority = draft.priority
    dueDate = draft.dueDate
    listID = draft.listID.flatMap(UUID.init)
  }
}

extension LocalTask {

  /// Decodes a ``LocalTask`` from `decoder`, defaulting `format` to `.markdown` when absent.
  ///
  /// The default preserves backward compatibility with JSON records written before the
  /// `format` field was introduced.
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(UUID.self, forKey: .id)
    title = try container.decode(String.self, forKey: .title)
    notes = try container.decodeIfPresent(String.self, forKey: .notes)
    format = try container.decodeIfPresent(NoteFormat.self, forKey: .format) ?? .markdown
    priority = try container.decode(TaskPriority.self, forKey: .priority)
    dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
    scheduledDate = try container.decodeIfPresent(Date.self, forKey: .scheduledDate)
    startDate = try container.decodeIfPresent(Date.self, forKey: .startDate)
    listID = try container.decodeIfPresent(UUID.self, forKey: .listID)
    isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
    completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
    createdAt = try container.decode(Date.self, forKey: .createdAt)
  }

  /// Creates a new incomplete task from a ``TaskDraft``.
  init(from draft: TaskDraft) {
    id = UUID()
    title = draft.title
    notes = draft.notes.isEmpty ? nil : draft.notes
    format = .markdown
    priority = draft.priority
    dueDate = draft.dueDate
    scheduledDate = nil
    startDate = nil
    listID = draft.listID.flatMap(UUID.init)
    isCompleted = false
    completedAt = nil
    createdAt = Date()
  }
}
