//
//  TaskRegistry.swift
//  Taskmato
//

import Foundation
import Observation

/// Manages the set of registered task providers and fans out queries across all enabled ones.
///
/// Providers are registered programmatically at app startup. The enabled/disabled state of
/// each provider is persisted to `UserDefaults` and restored on next launch.
///
/// **Selection model**: `selection` persists the sidebar's active view — either `.today` (the
/// smart Today list) or `.list(SelectedList)` (a specific provider list). The value is stored
/// verbatim and validated lazily once `providerLists` is populated via `setLists`. `.today` is
/// always immediately valid; `.list(...)` selections are treated as "no scope" (empty results)
/// until the first `setLists` call confirms the list exists.
///
/// **Migration**: on first launch after upgrading from the list-scope model, the initializer
/// removes the abandoned `"taskRegistry.providerListScopes"` and `"taskRegistry.selectedList"`
/// keys from `UserDefaults`.
@Observable
@MainActor
final class TaskRegistry {

  /// All providers that have been registered, ordered by `displayOrder` then `displayName`.
  private(set) var providers: [any TaskProvider] = []

  /// IDs of providers currently enabled by the user.
  private(set) var enabledIDs: Set<String>

  /// Lists loaded for each provider, keyed by provider ID.
  ///
  /// Populated by ``setLists(_:forProviderID:)``, which the sidebar calls after every
  /// `provider.lists()` load. Cleared for a provider when it is disabled. Views can
  /// observe this property to react when list data becomes available.
  private(set) var providerLists: [String: [TaskList]] = [:]

  /// The currently active sidebar selection.
  ///
  /// `.today` is always valid. `.list(...)` selections are validated lazily after
  /// `providerLists` is populated; treat a transient invalid `.list` as "no scope".
  /// Defaults to `.today` on first launch. Assignment auto-persists via `didSet`.
  var selection: SidebarSelection? {
    didSet { persistSelection() }
  }

  private let defaults: UserDefaults
  private let sorter: TaskSorter

  /// Fans out and orders task queries over this registry's enabled providers.
  ///
  /// Constructed lazily so it can capture `self`; the registry delegates its `tasks` and
  /// `completedTasks` methods to it during the registry split.
  @ObservationIgnored
  private(set) lazy var queryService = TaskQueryService(registry: self, sorter: sorter)

  private static let enabledKey = "taskRegistry.enabledProviderIDs"
  private static let selectionKey = "taskRegistry.selection"

  /// - Parameters:
  ///   - defaults: `UserDefaults` store for persistence. Override in tests.
  ///   - sorter: The task sorter used to order query results.
  init(defaults: UserDefaults = .standard, sorter: TaskSorter = TaskSorter()) {
    self.defaults = defaults
    self.sorter = sorter

    // One-shot migration: remove abandoned list-scope blobs from prior versions.
    defaults.removeObject(forKey: "taskRegistry.providerListScopes")
    defaults.removeObject(forKey: "taskRegistry.selectedList")

    let stored = defaults.stringArray(forKey: Self.enabledKey) ?? []
    self.enabledIDs = Set(stored)

    self.selection =
      defaults.data(forKey: Self.selectionKey).flatMap {
        try? JSONDecoder().decode(SidebarSelection.self, from: $0)
      } ?? .today
  }

  // MARK: - Registration

  /// Registers a provider so it appears in the registry. Does not enable it automatically.
  ///
  /// The `providers` array is re-sorted after insertion: ascending by `displayOrder`,
  /// then alphabetically by `displayName` when orders are equal.
  /// - Parameter provider: The provider to register.
  func register(_ provider: any TaskProvider) {
    guard !providers.contains(where: { $0.id == provider.id }) else { return }
    providers.append(provider)
    providers.sort { lhs, rhs in
      guard lhs.displayOrder == rhs.displayOrder else {
        return lhs.displayOrder < rhs.displayOrder
      }
      return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
    }
  }

  // MARK: - Enable / Disable

  /// Enables a registered provider so its tasks appear in fan-out queries.
  /// - Parameter provider: The provider to enable.
  func enable(_ provider: any TaskProvider) {
    enabledIDs.insert(provider.id)
    persist()
  }

  /// Disables a provider by ID, excluding it from future fan-out queries.
  ///
  /// Also clears the provider's list cache so downstream observers react immediately.
  /// - Parameter providerID: The `id` of the provider to disable.
  func disable(providerID: String) {
    enabledIDs.remove(providerID)
    providerLists.removeValue(forKey: providerID)
    persist()
    validateSelection()
  }

  /// Returns `true` if the provider with the given ID is currently enabled.
  /// - Parameter providerID: The provider ID to check.
  func isEnabled(_ providerID: String) -> Bool {
    enabledIDs.contains(providerID)
  }

  // MARK: - List cache

  /// Updates the list cache for `providerID` and validates the current selection.
  ///
  /// Call this after every `provider.lists()` load — on appear, after add, delete, or rename.
  func setLists(_ lists: [TaskList], forProviderID providerID: String) {
    providerLists[providerID] = lists
    validateSelection()
  }

  // MARK: - Selection

  /// Sets the active sidebar selection. Persistence happens automatically via `selection`'s `didSet`.
  /// - Parameter newSelection: The new selection, or `nil` to clear.
  func select(_ newSelection: SidebarSelection?) {
    selection = newSelection
  }

  /// Validates the current selection against the loaded `providerLists` cache and
  /// applies a fallback cascade when the selected list is no longer reachable.
  ///
  /// `.today` is always valid and is never changed. `.list(...)` selections are
  /// checked against `providerLists`; if the list is missing the cascade is:
  /// 1. First enabled writable provider's `defaultListID` (if in cache).
  /// 2. First list of the first enabled provider with lists in cache.
  /// 3. `.today`.
  func validateSelection() {
    guard case .list(let selectedList) = selection else { return }

    // Treat a nil cache as indeterminate only for registered, enabled providers whose
    // lists have not yet been loaded. Unknown or disabled providers get an empty cache
    // so the cascade fires normally.
    let providerKnown = providers.contains(where: {
      $0.id == selectedList.providerID && isEnabled($0.id)
    })
    let cache: [TaskList]? = providerKnown ? providerLists[selectedList.providerID] : []
    let listExists = cache?.contains(where: { $0.id == selectedList.listID }) ?? true
    if listExists { return }

    // Cascade 1: writable provider's default list.
    for provider in providers where isEnabled(provider.id) {
      guard let writable = provider as? (any WritableTaskProvider) else { continue }
      guard let defaultID = writable.defaultListID else { continue }
      guard providerLists[provider.id]?.contains(where: { $0.id == defaultID }) == true
      else { continue }
      select(.list(SelectedList(providerID: provider.id, listID: defaultID)))
      return
    }

    // Cascade 2: first list of first enabled provider.
    for provider in providers where isEnabled(provider.id) {
      if let lists = providerLists[provider.id], let first = lists.first {
        select(.list(SelectedList(providerID: provider.id, listID: first.id)))
        return
      }
    }

    // Cascade 3: always-valid Today.
    select(.today)
  }

  // MARK: - Queries

  /// Returns tasks described by the given query, sorted by the specified field and direction.
  ///
  /// Delegates to ``queryService``; see ``TaskQueryService/tasks(query:sortBy:direction:)``.
  func tasks(
    query: TaskQuery,
    sortBy field: TaskSortField,
    direction: TaskSortDirection
  ) async -> (tasks: [TaskItem], errors: [ProviderFetchError]) {
    await queryService.tasks(query: query, sortBy: field, direction: direction)
  }

  /// Returns completed tasks described by the given query, sorted by the specified field and direction.
  ///
  /// Delegates to ``queryService``; see ``TaskQueryService/completedTasks(query:sortBy:direction:)``.
  func completedTasks(
    query: TaskQuery,
    sortBy field: TaskSortField,
    direction: TaskSortDirection
  ) async -> (tasks: [TaskItem], errors: [ProviderFetchError]) {
    await queryService.completedTasks(query: query, sortBy: field, direction: direction)
  }

  // MARK: - Provider lookup

  /// Returns the registered provider that owns the given task reference, or `nil` if not found.
  /// - Parameter ref: The task reference whose provider to look up.
  func provider(for ref: TaskRef) -> (any TaskProvider)? {
    providers.first { $0.id == ref.providerID }
  }

  /// Returns the provider for a task reference if it conforms to `ClosableTaskProvider`, or `nil`.
  /// - Parameter ref: The task reference whose closable provider to look up.
  func closableProvider(for ref: TaskRef) -> (any ClosableTaskProvider)? {
    provider(for: ref) as? any ClosableTaskProvider
  }

  /// Returns the provider for a task reference if it conforms to `WritableTaskProvider`, or `nil`.
  /// - Parameter ref: The task reference whose writable provider to look up.
  func writableProvider(for ref: TaskRef) -> (any WritableTaskProvider)? {
    provider(for: ref) as? any WritableTaskProvider
  }

  /// Returns the first enabled provider conforming to `WritableTaskProvider`, or `nil`.
  var firstEnabledWritableProvider: (any WritableTaskProvider)? {
    providers.first { isEnabled($0.id) && $0 is (any WritableTaskProvider) }
      as? (any WritableTaskProvider)
  }

  /// Returns the enabled writable provider with the given ID, or `nil`.
  /// - Parameter id: The provider ID to resolve exactly.
  func enabledWritableProvider(id: String) -> (any WritableTaskProvider)? {
    providers.first { $0.id == id && isEnabled($0.id) }
      as? (any WritableTaskProvider)
  }

  /// Returns the preferred writable provider for new tasks.
  ///
  /// Resolution order:
  /// 1. The provider with `preferredID` if it is currently enabled and conforms to
  ///    ``WritableTaskProvider``.
  /// 2. ``firstEnabledWritableProvider`` — the first enabled writable provider in
  ///    registration order.
  ///
  /// Returns `nil` when no enabled writable provider is registered.
  /// - Parameter preferredID: A provider ID to try first, typically from ``AppSettings``
  ///   user preference. Pass `nil` to skip directly to the fallback.
  func resolveDefaultWritableProvider(preferredID: String?) -> (any WritableTaskProvider)? {
    if let preferredID, let writable = enabledWritableProvider(id: preferredID) {
      return writable
    }
    return firstEnabledWritableProvider
  }

  /// The authorization state of each registered provider, in registration order.
  ///
  /// Observe this in views to react when any provider's `isAuthorized` changes.
  var providerAuthorizationStates: [Bool] {
    providers.map(\.isAuthorized)
  }

  // MARK: - Persistence

  private func persist() {
    defaults.set(Array(enabledIDs), forKey: Self.enabledKey)
  }

  private func persistSelection() {
    guard let selection,
      let data = try? JSONEncoder().encode(selection)
    else {
      defaults.removeObject(forKey: Self.selectionKey)
      return
    }
    defaults.set(data, forKey: Self.selectionKey)
  }
}

// MARK: - Calendar helpers

extension Calendar {
  /// The last instant of today, DST-safe.
  ///
  /// Advances `startOfDay` by one calendar day and subtracts one second, rather than
  /// adding a fixed 86 400-second interval, so the result is correct on DST transition
  /// days when a civil day is 23 or 25 hours long.
  fileprivate var endOfToday: Date {
    let tomorrow = date(byAdding: .day, value: 1, to: startOfDay(for: Date())) ?? Date()
    return tomorrow.addingTimeInterval(-1)
  }
}
