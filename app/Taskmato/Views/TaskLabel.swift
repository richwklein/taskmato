//
//  TaskLabel.swift
//  Taskmato
//

/// String constants for task-action labels used across all task views.
///
/// `Tooltip` entries use sentence-style capitalization per the macOS HIG.
/// `Menu` entries use title-style capitalization per the macOS HIG.
enum TaskLabel {

  /// Tooltip strings for task action buttons — sentence-style capitalization.
  enum Tooltip {
    /// Shown on the completion circle when no session is running.
    static let markAsCompleted = "Mark as completed"
    /// Shown on the completion circle when a timer session is active.
    static let markAsCompletedActive = "Mark as completed (will stop timer)"
    /// Shown on the restore circle of a completed task row or card.
    static let restore = "Restore task"
    /// Shown on the trash button of a completed task row or card.
    static let deletePermanently = "Delete permanently"
  }

  /// Context menu item strings — title-style capitalization.
  enum Menu {
    /// Sets the task as active and switches to the timer tab.
    static let trackTask = "Track Task"
    /// Marks the task as completed via its closable provider.
    static let markAsCompleted = "Mark as Completed"
    /// Restores a completed task to the active list.
    static let restoreTask = "Restore Task"
    /// Permanently deletes a completed task via its writable provider.
    static let deletePermanently = "Delete Permanently"
  }
}
