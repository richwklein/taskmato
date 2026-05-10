//
//  TaskProvider.swift
//  Taskmato
//

import Foundation

/// A read-only source of tasks that can be listed, searched, and observed for live updates.
///
/// Conform to `MutableTaskProvider` in addition when the provider supports
/// completing or reopening tasks in the source system.
protocol TaskProvider: AnyObject, Sendable {

  /// Stable identifier used as `TaskRef.providerID` and for persisting enabled state.
  var id: String { get }

  /// Human-readable name shown in the Providers settings panel.
  var displayName: String { get }

  /// Whether this provider is free or requires a StoreKit purchase.
  var entitlement: ProviderEntitlement { get }

  /// Requests any permissions the provider needs (e.g. EventKit access, OAuth).
  ///
  /// Called lazily before the first `lists()` or `tasks(in:)` call.
  /// Throws if authorization fails or is denied.
  func authorize() async throws

  /// Returns all lists (groupings) available from this provider.
  func lists() async throws -> [TaskList]

  /// Returns incomplete tasks from the given list, or all tasks if `list` is `nil`.
  /// - Parameter list: The list to scope results to, or `nil` for all lists.
  func tasks(in list: TaskList?) async throws -> [TaskItem]

  /// Returns a stream that emits an updated task array whenever the provider's data changes.
  ///
  /// Return `nil` if the provider does not support live updates.
  func observe() -> AsyncStream<[TaskItem]>?
}

/// A `TaskProvider` that can also write completion state back to the source system.
protocol MutableTaskProvider: TaskProvider {

  /// Marks the task identified by `ref` as complete in the source system.
  /// - Parameter ref: The stable reference to the task to close.
  func complete(_ ref: TaskRef) async throws

  /// Reopens a previously completed task in the source system.
  /// - Parameter ref: The stable reference to the task to reopen.
  func reopen(_ ref: TaskRef) async throws

  /// Returns tasks that have been marked complete, for display in a "View Completed" sheet.
  ///
  /// The default implementation returns an empty array. Override when the provider
  /// supports surfacing completed tasks (e.g. a local JSON store or an Obsidian vault).
  func completedTasks() async throws -> [TaskItem]
}

extension MutableTaskProvider {
  func completedTasks() async throws -> [TaskItem] { [] }
}
