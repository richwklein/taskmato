//
//  TaskItemKind.swift
//  Taskmato
//

/// Distinguishes an active task from a completed one in the task picker views.
///
/// The kind drives the leading button, title style, primary-metadata slot, and optional
/// trailing delete button in both ``TaskRowView`` and ``TaskCardView``.
enum TaskItemKind {
  /// An incomplete task. `onComplete` is `nil` for read-only providers.
  case active(onComplete: (() -> Void)?)
  /// A completed task. `onDelete` is `nil` for non-writable providers.
  case completed(onRestore: () -> Void, onDelete: (() -> Void)?)
}
