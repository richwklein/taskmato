//
//  TaskRegistry.swift
//  Taskmato
//

import Foundation
import Observation

/// A per-provider error returned alongside tasks when a provider fetch fails.
typealias ProviderFetchError = (providerID: String, error: any Error)

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

  /// All providers that have been registered, in registration order.
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
  private static let enabledKey = "taskRegistry.enabledProviderIDs"
  private static let selectionKey = "taskRegistry.selection"

  /// - Parameter defaults: `UserDefaults` store for persistence. Override in tests.
  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults

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
  /// - Parameter provider: The provider to register.
  func register(_ provider: any TaskProvider) {
    guard !providers.contains(where: { $0.id == provider.id }) else { return }
    providers.append(provider)
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
  /// - `.singleList`: returns tasks from the named list, preserving provider section order.
  ///   Uses the `providerLists` cache to resolve the `TaskList`; falls back to a live fetch
  ///   if the cache is not yet populated.
  /// - `.crossProvider`: fans out across all enabled providers, applies the optional filter,
  ///   and sorts results globally (section boundaries are not preserved).
  ///
  /// - Parameters:
  ///   - query: Describes the scope and optional filter for the fetch.
  ///   - sortBy: The field to sort by.
  ///   - direction: The sort direction.
  /// - Returns: Matched tasks and any per-provider errors that occurred.
  func tasks(
    query: TaskQuery,
    sortBy field: TaskSortField,
    direction: TaskSortDirection
  ) async -> (tasks: [TaskItem], errors: [ProviderFetchError]) {
    let active = providers.filter { isEnabled($0.id) }

    switch query {
    case .singleList(let selectedList):
      guard
        let provider = providers.first(where: { $0.id == selectedList.providerID }),
        isEnabled(provider.id)
      else {
        return (tasks: [], errors: [])
      }
      let available: [TaskList]
      if let cached = providerLists[selectedList.providerID] {
        available = cached
      } else {
        available = (try? await provider.lists()) ?? []
      }
      guard let list = available.first(where: { $0.id == selectedList.listID }) else {
        return (tasks: [], errors: [])
      }
      let items = (try? await provider.tasks(in: list)) ?? []
      return (tasks: sortedByField(items, field: field, direction: direction), errors: [])

    case .crossProvider(let filter):
      let (all, errors) = await globalFanOut(providers: active)
      let filtered: [TaskItem]
      switch filter {
      case nil:
        filtered = all
      case .dueUpToToday:
        filtered = all.filter { item in
          guard let due = item.dueDate else { return false }
          return due <= Calendar.current.endOfToday
        }
      case .titleContains(let titleQuery):
        filtered = all.filter { $0.title.localizedCaseInsensitiveContains(titleQuery) }
      }
      return (
        tasks: sortedByField(filtered, field: field, direction: direction, preserveSections: false),
        errors: errors
      )
    }
  }

  /// Returns completed tasks described by the given query, sorted by the specified field and direction.
  ///
  /// Fans out `completedTasks()` across all enabled ``ClosableTaskProvider``s, applies the same
  /// filter logic as ``tasks(query:sortBy:direction:)``, and sorts the flat result globally.
  ///
  /// - Parameters:
  ///   - query: Describes the scope and optional filter for the fetch.
  ///   - sortBy: The field to sort by.
  ///   - direction: The sort direction.
  /// - Returns: Matched completed tasks and any per-provider errors that occurred.
  func completedTasks(
    query: TaskQuery,
    sortBy field: TaskSortField,
    direction: TaskSortDirection
  ) async -> (tasks: [TaskItem], errors: [ProviderFetchError]) {
    var all: [TaskItem] = []
    var providerErrors: [ProviderFetchError] = []

    await withTaskGroup(of: (items: [TaskItem], fetchError: ProviderFetchError?).self) { group in
      for provider in providers where isEnabled(provider.id) {
        guard let closable = provider as? (any ClosableTaskProvider) else { continue }
        let providerID = provider.id
        group.addTask {
          do {
            let items = try await closable.completedTasks()
            return (items: items, fetchError: nil)
          } catch {
            return (items: [], fetchError: (providerID: providerID, error: error))
          }
        }
      }
      for await result in group {
        all.append(contentsOf: result.items)
        if let fetchError = result.fetchError {
          providerErrors.append(fetchError)
        }
      }
    }

    let filtered: [TaskItem]
    switch query {
    case .singleList(let selectedList):
      filtered = all.filter { $0.list?.id == selectedList.listID }
    case .crossProvider(let filter):
      switch filter {
      case nil:
        filtered = all
      case .dueUpToToday:
        let startOfToday = Calendar.current.startOfDay(for: Date())
        filtered = all.filter { ($0.completedAt ?? .distantPast) >= startOfToday }
      case .titleContains(let titleQuery):
        filtered = all.filter { $0.title.localizedCaseInsensitiveContains(titleQuery) }
      }
    }

    return (
      tasks: sortedByField(filtered, field: field, direction: direction, preserveSections: false),
      errors: providerErrors
    )
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

  /// Returns the first enabled provider conforming to `WritableTaskProvider`, or `nil`.
  var firstEnabledWritableProvider: (any WritableTaskProvider)? {
    providers.first { isEnabled($0.id) && $0 is (any WritableTaskProvider) }
      as? (any WritableTaskProvider)
  }

  /// The authorization state of each registered provider, in registration order.
  ///
  /// Observe this in views to react when any provider's `isAuthorized` changes.
  var providerAuthorizationStates: [Bool] {
    providers.map(\.isAuthorized)
  }

  // MARK: - Private helpers

  private func globalFanOut(providers: [any TaskProvider]) async -> (
    [TaskItem], [ProviderFetchError]
  ) {
    var merged: [TaskItem] = []
    var providerErrors: [ProviderFetchError] = []

    await withTaskGroup(of: (items: [TaskItem], fetchError: ProviderFetchError?).self) { group in
      for provider in providers {
        let providerID = provider.id
        group.addTask {
          do {
            let allLists = try await provider.lists()
            let items: [TaskItem]
            if allLists.isEmpty {
              items = try await provider.tasks(in: nil)
            } else {
              var scoped: [TaskItem] = []
              for list in allLists {
                scoped += try await provider.tasks(in: list)
              }
              items = scoped
            }
            return (items: items, fetchError: nil)
          } catch {
            return (items: [], fetchError: (providerID: providerID, error: error))
          }
        }
      }
      for await result in group {
        merged.append(contentsOf: result.items)
        if let fetchError = result.fetchError {
          providerErrors.append(fetchError)
        }
      }
    }

    return (merged, providerErrors)
  }

  /// Sorts `items` by `field`/`direction`, applying the sort within each `(list.id, section)`
  /// group in encounter order. Groups are then flattened back to a single array, preserving
  /// the section order the providers produced.
  private func sortedByField(
    _ items: [TaskItem],
    field: TaskSortField,
    direction: TaskSortDirection,
    preserveSections: Bool = true
  ) -> [TaskItem] {
    guard preserveSections else {
      return items.sorted { compareItems($0, $1, field: field, direction: direction) }
    }

    struct SectionKey: Hashable {
      let listID: String
      let section: String?
    }

    var ordered: [SectionKey] = []
    var bySection: [SectionKey: [TaskItem]] = [:]

    for item in items {
      let key = SectionKey(listID: item.list?.id ?? "", section: item.section)
      if bySection[key] == nil { ordered.append(key) }
      bySection[key, default: []].append(item)
    }

    return ordered.flatMap { key in
      (bySection[key] ?? []).sorted { compareItems($0, $1, field: field, direction: direction) }
    }
  }

  private func compareItems(
    _ lhs: TaskItem, _ rhs: TaskItem, field: TaskSortField, direction: TaskSortDirection
  ) -> Bool {
    let asc = direction == .ascending
    switch field {
    case .dueDate:
      return compareDatesNilLast(lhs.dueDate, rhs.dueDate, ascending: asc)
        ?? compareTitlesAscending(lhs.title, rhs.title)
        ?? compareRefs(lhs.id, rhs.id)
    case .priority:
      if lhs.priority != rhs.priority {
        return asc ? lhs.priority < rhs.priority : lhs.priority > rhs.priority
      }
      return compareDatesNilLast(lhs.dueDate, rhs.dueDate, ascending: true)
        ?? compareTitlesAscending(lhs.title, rhs.title)
        ?? compareRefs(lhs.id, rhs.id)
    case .title:
      let cmp = lhs.title.localizedStandardCompare(rhs.title)
      if cmp != .orderedSame { return asc ? cmp == .orderedAscending : cmp == .orderedDescending }
      return compareRefs(lhs.id, rhs.id)
    case .creationDate:
      return compareDatesNilLast(lhs.createdAt, rhs.createdAt, ascending: asc)
        ?? compareTitlesAscending(lhs.title, rhs.title)
        ?? compareRefs(lhs.id, rhs.id)
    }
  }

  /// Compares two optional dates with nil-last semantics. Returns `nil` when both are equal or both nil.
  private func compareDatesNilLast(_ lhs: Date?, _ rhs: Date?, ascending: Bool) -> Bool? {
    switch (lhs, rhs) {
    case (let lhsDate?, let rhsDate?):
      guard lhsDate != rhsDate else { return nil }
      return ascending ? lhsDate < rhsDate : lhsDate > rhsDate
    case (.some, .none): return true
    case (.none, .some): return false
    case (.none, .none): return nil
    }
  }

  /// Ascending title comparison using `localizedStandardCompare`. Returns `nil` when equal.
  private func compareTitlesAscending(_ lhs: String, _ rhs: String) -> Bool? {
    let result = lhs.localizedStandardCompare(rhs)
    return result == .orderedSame ? nil : result == .orderedAscending
  }

  /// Deterministic tiebreaker using the lexicographic order of `providerID/nativeID`.
  private func compareRefs(_ lhs: TaskRef, _ rhs: TaskRef) -> Bool {
    "\(lhs.providerID)/\(lhs.nativeID)" < "\(rhs.providerID)/\(rhs.nativeID)"
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
  /// The last second of today: start of day + 86399 seconds.
  fileprivate var endOfToday: Date {
    startOfDay(for: Date()).addingTimeInterval(86400 - 1)
  }
}
