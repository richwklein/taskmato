//
//  ProviderListScope.swift
//  Taskmato
//

import Foundation

/// Persists which lists a single provider exposes in the task picker.
///
/// A `nil` ``visibleListIDs`` means all lists are visible (the default state).
/// Once the user hides at least one list the set is seeded with all known list IDs
/// and the hidden list is removed, so future additions default to visible.
struct ProviderListScope: Codable, Sendable, Equatable {

  /// The set of list IDs visible in the picker, or `nil` when all lists are visible.
  var visibleListIDs: Set<String>?

  /// Returns `true` if the list with `listID` should appear in the task picker.
  ///
  /// When ``visibleListIDs`` is `nil` all lists are considered visible.
  func isVisible(_ listID: String) -> Bool {
    visibleListIDs.map { $0.contains(listID) } ?? true
  }

  /// Updates the visibility of `listID`.
  ///
  /// - Parameters:
  ///   - listID: The list whose visibility changes.
  ///   - visible: `true` to show, `false` to hide.
  ///   - allListIDs: All list IDs currently known for this provider, used to seed
  ///     ``visibleListIDs`` the first time a list is hidden.
  mutating func setVisible(_ listID: String, visible: Bool, allListIDs: Set<String>) {
    if visible {
      visibleListIDs?.insert(listID)
      // Reset to nil (all visible) once every ID is back in the set.
      if let ids = visibleListIDs, ids == allListIDs {
        visibleListIDs = nil
      }
    } else {
      if visibleListIDs == nil {
        visibleListIDs = allListIDs
      }
      visibleListIDs?.remove(listID)
    }
  }
}
