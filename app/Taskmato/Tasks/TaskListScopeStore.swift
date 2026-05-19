//
//  TaskListScopeStore.swift
//  Taskmato
//

import Foundation
import Observation

/// Persists per-provider list visibility for the task picker.
///
/// The default state is "show all." Hiding a list stores its ID in a per-provider
/// exclusion set in `UserDefaults`; the list reappears as soon as it is re-enabled.
@Observable
@MainActor
final class TaskListScopeStore {

  private var hidden: [String: Set<String>] = [:]
  private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  /// Returns `true` when `listID` should appear in the task picker for `providerID`.
  func isListEnabled(_ listID: String, for providerID: String) -> Bool {
    ensureLoaded(for: providerID)
    return !(hidden[providerID]?.contains(listID) ?? false)
  }

  /// Toggles the visibility of `listID` for `providerID` and persists the change.
  func toggleList(_ listID: String, for providerID: String) {
    ensureLoaded(for: providerID)
    var set = hidden[providerID] ?? []
    if set.contains(listID) { set.remove(listID) } else { set.insert(listID) }
    hidden[providerID] = set
    persist(for: providerID)
  }

  /// Removes all hidden-list overrides for `providerID`, restoring full visibility.
  func clearScope(for providerID: String) {
    hidden[providerID] = Set()
    defaults.removeObject(forKey: key(for: providerID))
  }

  // MARK: - Private helpers

  private func ensureLoaded(for providerID: String) {
    guard hidden[providerID] == nil else { return }
    let stored = defaults.array(forKey: key(for: providerID)) as? [String] ?? []
    hidden[providerID] = Set(stored)
  }

  private func persist(for providerID: String) {
    let set = hidden[providerID] ?? []
    if set.isEmpty {
      defaults.removeObject(forKey: key(for: providerID))
    } else {
      defaults.set(Array(set), forKey: key(for: providerID))
    }
  }

  private func key(for providerID: String) -> String {
    "taskListScope.\(providerID)"
  }
}
