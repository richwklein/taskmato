//
//  TaskList.swift
//  Taskmato
//

import Foundation

/// A named grouping of tasks within a single provider (e.g. a Reminders list, an Obsidian folder, a Todoist project).
nonisolated struct TaskList: Identifiable, Hashable, Codable, Sendable {

  /// Provider-local identifier for this list.
  let id: String

  /// The identifier of the provider that owns this list.
  let providerID: ProviderID

  /// Human-readable name shown in the picker.
  let name: String
}
