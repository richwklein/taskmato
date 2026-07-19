//
//  TaskRef.swift
//  Taskmato
//

import Foundation

/// A stable, provider-namespaced identifier for a task.
///
/// Combining `providerID` and `nativeID` allows tasks from multiple
/// concurrent providers to coexist without collisions.
struct TaskRef: Hashable, Codable, Sendable {

  /// The identifier of the provider that owns this task (e.g. `"reminders"`, `"obsidian"`, `"cli"`).
  let providerID: String

  /// The provider-local identifier for the task (e.g. an EventKit calendar item ID or a file-path hash).
  let nativeID: String
}
