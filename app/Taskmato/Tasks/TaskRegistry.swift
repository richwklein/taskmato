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
/// Providers are registered programmatically at app startup. The enabled/disabled
/// state of each provider is persisted to `UserDefaults` and restored on next launch.
@Observable
@MainActor
final class TaskRegistry {

  /// All providers that have been registered, in registration order.
  private(set) var providers: [any TaskProvider] = []

  /// IDs of providers currently enabled by the user.
  private(set) var enabledIDs: Set<String>

  /// Per-provider list visibility scopes, keyed by provider ID.
  private(set) var scopes: [String: ProviderListScope]

  private let defaults: UserDefaults
  private static let enabledKey = "taskRegistry.enabledProviderIDs"
  private static let scopesKey = "taskRegistry.providerListScopes"

  /// - Parameter defaults: `UserDefaults` store for enabled-state persistence. Override in tests.
  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    let stored = defaults.stringArray(forKey: Self.enabledKey) ?? []
    self.enabledIDs = Set(stored)
    self.scopes =
      defaults.data(forKey: Self.scopesKey)
      .flatMap { try? JSONDecoder().decode([String: ProviderListScope].self, from: $0) } ?? [:]
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
  /// - Parameter providerID: The `id` of the provider to disable.
  func disable(providerID: String) {
    enabledIDs.remove(providerID)
    persist()
  }

  /// Returns `true` if the provider with the given ID is currently enabled.
  /// - Parameter providerID: The provider ID to check.
  func isEnabled(_ providerID: String) -> Bool {
    enabledIDs.contains(providerID)
  }

  // MARK: - Queries

  /// Returns tasks from all enabled providers, optionally filtered by a search string.
  ///
  /// Results from each provider are fetched concurrently. Provider errors are collected
  /// and returned alongside results so the UI can surface them without blocking other providers.
  /// Tasks are sorted by priority (descending) then due date (ascending, nil last).
  ///
  /// - Parameter query: Case-insensitive substring to match against task titles.
  ///   Pass an empty string to return all tasks.
  /// - Returns: A tuple of matched tasks and any per-provider errors that occurred.
  func tasks(matching query: String) async -> (tasks: [TaskItem], errors: [ProviderFetchError]) {
    let active = providers.filter { isEnabled($0.id) }
    var merged: [TaskItem] = []
    var providerErrors: [ProviderFetchError] = []

    await withTaskGroup(of: (items: [TaskItem], fetchError: ProviderFetchError?).self) { group in
      for provider in active {
        let providerID = provider.id
        let scope = scopes[providerID]
        group.addTask {
          do {
            let allLists = try await provider.lists()
            let items: [TaskItem]
            if allLists.isEmpty {
              // Provider declares no lists; fetch all tasks unscoped.
              items = try await provider.tasks(in: nil)
            } else {
              let visibleLists = allLists.filter { scope?.isVisible($0.id) ?? true }
              var scoped: [TaskItem] = []
              for list in visibleLists {
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

    if !query.isEmpty {
      merged = merged.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    return (tasks: sortedByPriorityThenDueDate(merged), errors: providerErrors)
  }

  private func sortedByPriorityThenDueDate(_ items: [TaskItem]) -> [TaskItem] {
    items.sorted { lhs, rhs in
      if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
      switch (lhs.dueDate, rhs.dueDate) {
      case (let lhsDate?, let rhsDate?): return lhsDate < rhsDate
      case (.some, .none): return true
      case (.none, .some): return false
      case (.none, .none): return false
      }
    }
  }

  /// Returns the registered provider that owns the given task reference, or `nil` if not found.
  /// - Parameter ref: The task reference whose provider to look up.
  func provider(for ref: TaskRef) -> (any TaskProvider)? {
    providers.first { $0.id == ref.providerID }
  }

  /// Returns the provider for a task reference if it conforms to `MutableTaskProvider`, or `nil`.
  /// - Parameter ref: The task reference whose mutable provider to look up.
  func mutableProvider(for ref: TaskRef) -> (any MutableTaskProvider)? {
    provider(for: ref) as? any MutableTaskProvider
  }

  // MARK: - List scoping

  /// Returns `true` if the list with `listID` is visible for the given provider.
  ///
  /// Defaults to `true` when no scope has been configured for the provider.
  func isListVisible(_ listID: String, providerID: String) -> Bool {
    scopes[providerID]?.isVisible(listID) ?? true
  }

  /// Updates the visibility of a list within a provider's scope.
  ///
  /// - Parameters:
  ///   - listID: The list whose visibility changes.
  ///   - providerID: The provider that owns the list.
  ///   - visible: `true` to show, `false` to hide.
  ///   - allListIDs: All list IDs currently known for the provider. Used to seed the
  ///     scope the first time a list is hidden.
  func setListVisible(
    _ listID: String,
    providerID: String,
    visible: Bool,
    allListIDs: Set<String>
  ) {
    var scope = scopes[providerID] ?? ProviderListScope()
    scope.setVisible(listID, visible: visible, allListIDs: allListIDs)
    scopes[providerID] = scope
    persistScopes()
  }

  // MARK: - Persistence

  private func persist() {
    defaults.set(Array(enabledIDs), forKey: Self.enabledKey)
  }

  private func persistScopes() {
    guard let data = try? JSONEncoder().encode(scopes) else { return }
    defaults.set(data, forKey: Self.scopesKey)
  }
}
