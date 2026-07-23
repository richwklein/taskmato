//
//  SelectionStore.swift
//  Taskmato
//

import Foundation
import Observation

/// Owns the sidebar's active selection and keeps it valid as providers and lists change.
///
/// This is the selection concern extracted from the former `ProviderRegistry` façade. It is the
/// task-scope selection **sink**: the sidebar binds ``selection`` directly today, and the
/// window-first shell later forwards destinations into it via ``select(_:)`` (design doc 0008,
/// D4). Either way `SelectionStore` owns the 3-step validation cascade.
///
/// **Selection model**: `selection` is either `.today` (the smart Today list) or
/// `.list(SelectedList)` (a specific provider list). The value is stored verbatim and validated
/// once the registry's `providerLists` cache is populated. `.today` is always immediately valid;
/// a `.list(...)` selection is treated as "no scope" until the cache confirms the list exists.
///
/// **Migration**: on first launch after upgrading from the list-scope model, the initializer
/// removes the abandoned `"taskRegistry.selectedList"` key from `UserDefaults`.
@Observable
@MainActor
final class SelectionStore {

  /// The currently active sidebar selection.
  ///
  /// `.today` is always valid. `.list(...)` selections are validated after `providerLists`
  /// is populated; treat a transient invalid `.list` as "no scope". Defaults to `.today` on
  /// first launch. Assignment auto-persists via `didSet`.
  var selection: SidebarSelection? {
    didSet { persistSelection() }
  }

  // Held strongly: the composition root owns both, and the registry only references this
  // store weakly (via `onProviderStateChanged`), so there is no retain cycle. A strong
  // reference keeps the cascade safe even if no other owner outlives this store.
  @ObservationIgnored private let registry: ProviderRegistry
  @ObservationIgnored private let defaults: UserDefaults
  private static let selectionKey = "taskRegistry.selection"

  /// - Parameters:
  ///   - registry: The registry supplying providers, enabled state, and the list cache.
  ///   - defaults: `UserDefaults` store for persistence. Override in tests.
  init(registry: ProviderRegistry, defaults: UserDefaults = .standard) {
    self.registry = registry
    self.defaults = defaults

    // One-shot migration: remove the abandoned selected-list blob from prior versions.
    defaults.removeObject(forKey: "taskRegistry.selectedList")

    self.selection =
      defaults.data(forKey: Self.selectionKey).flatMap {
        try? JSONDecoder().decode(SidebarSelection.self, from: $0)
      } ?? .today
  }

  /// Sets the active sidebar selection. Persistence happens automatically via `selection`'s `didSet`.
  /// - Parameter newSelection: The new selection, or `nil` to clear.
  func select(_ newSelection: SidebarSelection?) {
    selection = newSelection
  }

  /// Validates the current selection against the registry's `providerLists` cache and
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
    let providerKnown = registry.providers.contains(where: {
      $0.id == selectedList.providerID && registry.isEnabled($0.id)
    })
    let cache: [TaskList]? = providerKnown ? registry.providerLists[selectedList.providerID] : []
    let listExists = cache?.contains(where: { $0.id == selectedList.listID }) ?? true
    if listExists { return }

    // Cascade 1: writable provider's default list.
    for provider in registry.providers where registry.isEnabled(provider.id) {
      guard let writable = provider as? (any WritableTaskProvider) else { continue }
      guard let defaultID = writable.defaultListID else { continue }
      guard registry.providerLists[provider.id]?.contains(where: { $0.id == defaultID }) == true
      else { continue }
      select(.list(SelectedList(providerID: provider.id, listID: defaultID)))
      return
    }

    // Cascade 2: first list of first enabled provider.
    for provider in registry.providers where registry.isEnabled(provider.id) {
      if let lists = registry.providerLists[provider.id], let first = lists.first {
        select(.list(SelectedList(providerID: provider.id, listID: first.id)))
        return
      }
    }

    // Cascade 3: always-valid Today.
    select(.today)
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
