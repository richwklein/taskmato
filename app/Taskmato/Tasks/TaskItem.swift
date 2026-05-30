//
//  TaskItem.swift
//  Taskmato
//

import Foundation

/// An immutable, provider-agnostic representation of a single task.
///
/// `TaskItem` is the shared currency between all task providers, the picker UI,
/// and the session log. Providers map their native task types to this struct;
/// display layers read from it without knowing which provider it came from.
struct TaskItem: Identifiable, Hashable, Codable, Sendable {

  /// Stable, provider-namespaced identifier.
  let id: TaskRef

  /// The task title shown in the picker and active-task label.
  var title: String

  /// Optional supplementary notes or description.
  var notes: String?

  /// How `title` and `notes` should be rendered — plain text or markdown.
  var format: NoteFormat

  /// Priority level, used for sorting and badging in the picker.
  var priority: TaskPriority

  /// The date by which the task is due.
  var dueDate: Date?

  /// The date the task is scheduled to be worked on.
  var scheduledDate: Date?

  /// The earliest date the task should appear in the picker.
  var startDate: Date?

  /// The list this task belongs to, if any.
  var list: TaskList?

  /// An optional sub-grouping within a list (e.g. a Todoist section).
  var section: String?

  /// A deep link back to the task in the source provider app, if available.
  var sourceURL: URL?

  /// Wall-clock time the task was completed, or `nil` for active tasks.
  ///
  /// Populated by ``ClosableTaskProvider/completedTasks()``; always `nil` for live tasks.
  var completedAt: Date?
}
