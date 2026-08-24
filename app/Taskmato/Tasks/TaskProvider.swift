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
  var id: ProviderID { get }

  /// Human-readable name shown in the Providers settings panel.
  var displayName: String { get }

  /// Relative display position when listing providers in the sidebar and add-provider menu.
  ///
  /// Lower values appear first. Providers that do not override this property default to
  /// `Int.max` and are then ordered alphabetically by `displayName` among themselves.
  var displayOrder: Int { get }

  /// SF Symbol name used to represent this provider in the UI.
  var icon: String { get }

  /// Semantic color used to represent this provider in charts and legends.
  ///
  /// Defaults to ``ProviderTint/gray``; providers override it to claim a distinct hue.
  var tint: ProviderTint { get }

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

  /// Returns all sections (e.g. markdown headings) available within `list`, in document order,
  /// whether or not they currently contain any tasks.
  ///
  /// Sections are an organizational concept independent of writability — a read-only provider
  /// could group tasks by section too. Providers that don't group tasks into sections return an
  /// empty array; only ``ObsidianProvider`` currently overrides this.
  /// - Parameter list: The list to scan for sections.
  func sections(in list: TaskList) async throws -> [String]

  /// Returns a stream that emits an updated task array whenever the provider's data changes.
  ///
  /// Return `nil` if the provider does not support live updates.
  func observe() -> AsyncStream<[TaskItem]>?

  /// Returns whether `task` represents the persisted reference `ref`.
  ///
  /// The default requires exact equality. Providers whose native identifiers can evolve while
  /// preserving task identity may override this to support legacy references and migration.
  /// - Parameters:
  ///   - ref: The persisted or externally supplied task reference.
  ///   - task: A freshly loaded provider task.
  func matches(_ ref: TaskRef, to task: TaskItem) -> Bool

  /// Resolves a persisted reference against freshly loaded tasks, or returns `nil` when absent.
  func resolve(_ ref: TaskRef, among tasks: [TaskItem]) -> TaskItem?
}

extension TaskProvider {
  var isAuthorized: Bool { true }
  var displayOrder: Int { Int.max }
  var tint: ProviderTint { .gray }
  func sections(in list: TaskList) async throws -> [String] { [] }
  func matches(_ ref: TaskRef, to task: TaskItem) -> Bool { ref == task.id }
  func resolve(_ ref: TaskRef, among tasks: [TaskItem]) -> TaskItem? {
    tasks.first { matches(ref, to: $0) }
  }
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

extension WritableTaskProvider {
  var supportsDueTime: Bool { true }

  /// Providers without list-affecting configuration use the empty token, which never changes.
  var listConfiguration: ListConfigurationToken { ListConfigurationToken() }
}

/// A `ClosableTaskProvider` that also supports creating and updating tasks, and choosing a
/// default target list from among the provider's existing lists.
///
/// `LocalProvider` and `RemindersProvider` conform. Providers that also need to create,
/// rename, or delete lists (not just tasks) conform to ``WritableListProvider`` instead.
protocol WritableTaskProvider: ClosableTaskProvider {

  /// The ID of the list new tasks target by default, or `nil` if none is set.
  var defaultListID: String? { get }

  /// The `ContentFormat` this provider creates new tasks with.
  var contentFormat: ContentFormat { get }

  /// Whether this provider persists `TaskDraft.dueDateIncludesTime`/`TaskItem.dueDateIncludesTime`.
  ///
  /// `true` by default. Providers whose native format has no time-of-day convention (e.g.
  /// Obsidian's `📅 YYYY-MM-DD`, which always writes date-only) override this to `false` so the
  /// Add Task dialog doesn't offer a "due time" affordance that would silently be dropped.
  var supportsDueTime: Bool { get }

  /// A value that changes whenever the configuration determining ``lists()`` membership changes
  /// (an edited pattern filter or a switched source), letting views know when to reload cached
  /// lists.
  var listConfiguration: ListConfigurationToken { get }

  /// Creates a new task from `draft` and returns the resulting item.
  ///
  /// If `draft.listID` is `nil` the provider uses its default list.
  @discardableResult
  func addTask(_ draft: TaskDraft) async throws -> TaskItem

  /// Persists `listID` as the default target for new tasks.
  /// - Throws: if `listID` does not identify one of the provider's current ``lists()``.
  func setDefaultList(_ listID: String) async throws

  /// Updates the task identified by `ref` with values from `draft`.
  /// - Throws: if the task cannot be found or the update fails.
  func updateTask(_ ref: TaskRef, draft: TaskDraft) async throws

  /// Permanently removes the task identified by `ref` from the provider's store.
  /// - Throws: if the task cannot be found or removal fails.
  func deleteTask(_ ref: TaskRef) async throws
}

/// A `WritableTaskProvider` that also owns list lifecycle: create, rename, and delete.
///
/// Only providers where Taskmato is the sole or primary owner of the list structure (e.g.
/// `LocalProvider`) conform. Providers backed by a system with its own mature list-management
/// UI (e.g. Reminders.app for `RemindersProvider`) conform to ``WritableTaskProvider`` only.
protocol WritableListProvider: WritableTaskProvider {

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
}
