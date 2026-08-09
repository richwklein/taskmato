//
//  TaskItemPresenter.swift
//  Taskmato
//

import Foundation

/// Derives the display values and action affordances shared by ``TaskRowView`` and
/// ``TaskCardView`` from a task, its ``TaskItemKind``, and optional ``TaskLineage``.
///
/// The presenter holds the logic both views would otherwise duplicate — completed-state
/// detection, due-date urgency, the completed subtitle, the lineage-visibility gate, and the
/// kind-derived complete/restore/delete affordances — leaving the views as layout-only shells.
/// It exposes plain values (no SwiftUI `View` types), so its rules are unit-testable directly.
struct TaskItemPresenter {

  /// The task being presented.
  let task: TaskItem
  /// Whether the task is active or completed, carrying the relevant action closures.
  let kind: TaskItemKind
  /// The task's provenance, shown only in cross-provider flat modes (Today, search).
  let lineage: TaskLineage?

  /// - Parameters:
  ///   - task: The task being presented.
  ///   - kind: The active/completed kind and its action closures.
  ///   - lineage: The task's provenance, or `nil` when not in a flat cross-provider mode.
  init(task: TaskItem, kind: TaskItemKind, lineage: TaskLineage? = nil) {
    self.task = task
    self.kind = kind
    self.lineage = lineage
  }

  /// `true` when the task is completed.
  var isCompleted: Bool {
    if case .completed = kind { return true }
    return false
  }

  // MARK: - Action affordances

  /// The complete action, present only for an active task whose provider supports completion.
  var onComplete: (() -> Void)? {
    if case .active(let onComplete, _) = kind { return onComplete }
    return nil
  }

  /// The restore action, present for any completed task.
  var onRestore: (() -> Void)? {
    if case .completed(let onRestore, _) = kind { return onRestore }
    return nil
  }

  /// The permanent-delete action, present for an active or completed task on a writable provider.
  var onDelete: (() -> Void)? {
    switch kind {
    case .active(_, let onDelete): return onDelete
    case .completed(_, let onDelete): return onDelete
    }
  }

  /// Whether the leading control is a hover-toggling completion circle (active + completable).
  var showsCompletionToggle: Bool { onComplete != nil }

  /// Whether the leading control is a filled restore circle (any completed task).
  var showsRestore: Bool { isCompleted }

  /// Whether a trailing permanent-delete control should be offered.
  var canDelete: Bool { onDelete != nil }

  // MARK: - Metadata

  /// The due date to display, or `nil` — suppressed for completed tasks, which show the
  /// completed subtitle instead.
  var dueDate: Date? { isCompleted ? nil : task.dueDate }

  /// Whether ``dueDate`` carries a meaningful time-of-day, or is date-only.
  var dueDateIncludesTime: Bool { isCompleted ? false : task.dueDateIncludesTime }

  /// `true` when the due date is today or already past.
  var dueIsUrgent: Bool { task.dueDate?.isUrgentDueDate ?? false }

  /// The lineage to display, or `nil` when there is nothing meaningful to show.
  var displayLineage: TaskLineage? {
    guard let lineage, !lineage.isEmpty else { return nil }
    return lineage
  }

  /// A relative description of when the task was completed, e.g. "2 days ago".
  var completedSubtitle: String {
    task.completedAt.map {
      RelativeDateTimeFormatter().localizedString(for: $0, relativeTo: Date())
    } ?? "Unknown date"
  }
}
