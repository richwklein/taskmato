//
//  TaskProvider.swift
//  Taskmato
//

import Foundation

/// A read-only source of tasks that can be listed, searched, and observed for live updates.
///
/// Conform to `ClosableTaskProvider` in addition when the provider supports
/// completing or reopening tasks in the source system.
protocol TaskProvider: AnyObject, Sendable {

  /// Stable identifier used as `TaskRef.providerID` and for persisting enabled state.
  var id: String { get }

  /// Human-readable name shown in the Providers settings panel.
  var displayName: String { get }

  /// SF Symbol name used to represent this provider in the UI.
  var icon: String { get }

  /// Whether this provider is free or requires a StoreKit purchase.
  var entitlement: ProviderEntitlement { get }

  /// Whether this provider currently has the access it needs to serve tasks.
  ///
  /// Defaults to `true`. Providers that require explicit user authorization
  /// (e.g. EventKit) override this to reflect live permission state.
  var isAuthorized: Bool { get }

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

extension TaskProvider {
  var isAuthorized: Bool { true }
}

/// A `TaskProvider` that supports toggling task completion state in the source system.
protocol ClosableTaskProvider: TaskProvider {

  /// Marks the task identified by `ref` as complete in the source system.
  /// - Parameter ref: The stable reference to the task to close.
  func complete(_ ref: TaskRef) async throws

  /// Reopens a previously completed task in the source system.
  /// - Parameter ref: The stable reference to the task to reopen.
  func reopen(_ ref: TaskRef) async throws

  /// Returns tasks that have been marked complete, for display in the "View Completed" section.
  ///
  /// The default implementation returns an empty array. Override when the provider
  /// supports surfacing completed tasks (e.g. a local JSON store or an Obsidian vault).
  func completedTasks() async throws -> [TaskItem]
}

extension ClosableTaskProvider {
  func completedTasks() async throws -> [TaskItem] { [] }
}

/// A `ClosableTaskProvider` that also supports creating tasks and managing lists.
///
/// Providers conforming to this protocol expose the full write surface: task creation,
/// list lifecycle (create, rename, delete), task deletion, and a persistent default-list
/// preference. `LocalProvider` conforms immediately; `ObsidianProvider` and
/// `RemindersProvider` will conform in follow-on milestones.
protocol WritableTaskProvider: ClosableTaskProvider {

  /// The ID of the list new tasks target by default, or `nil` if none is set.
  var defaultListID: String? { get }

  /// Creates a new task from `draft` and returns the resulting item.
  ///
  /// If `draft.listID` is `nil` the provider uses its default list.
  @discardableResult
  func addTask(_ draft: TaskDraft) async throws -> TaskItem

  /// Persists `listID` as the default target for new tasks.
  /// - Throws: if `listID` does not identify a known list.
  func setDefaultList(_ listID: String) async throws

  /// Creates a new list with `name` and returns the provider-agnostic ``TaskList``.
  @discardableResult
  func createList(name: String) async throws -> TaskList

  /// Renames the list identified by `listID` to `name`.
  /// - Throws: if `listID` does not identify a known list.
  func renameList(_ listID: String, name: String) async throws

  /// Deletes the list identified by `listID`, reassigning its tasks to the default list.
  ///
  /// The default list cannot be deleted; call ``setDefaultList(_:)`` first to promote
  /// another list before deleting the current default.
  /// - Throws: if `listID` is the default list or does not identify a known list.
  func deleteList(_ listID: String) async throws

  /// Permanently removes the task identified by `ref` from the provider's store.
  /// - Throws: if the task cannot be found or removal fails.
  func deleteTask(_ ref: TaskRef) async throws
}
