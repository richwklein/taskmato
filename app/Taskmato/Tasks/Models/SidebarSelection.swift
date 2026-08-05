//
//  SidebarSelection.swift
//  Taskmato
//

import Foundation

/// The selection state of the sidebar — either the Today smart list or a specific provider list.
enum SidebarSelection: Hashable, Codable, Sendable {

  /// The Today smart view — tasks due on or before the end of today, across all enabled providers.
  case today

  /// A specific provider list identified by provider and list IDs.
  case list(SelectedList)

  /// Returns the list ID when this selection belongs to `providerID`.
  /// - Parameter providerID: The provider ID to match against this selection.
  func listID(matching providerID: ProviderID) -> String? {
    guard case .list(let selectedList) = self,
      selectedList.providerID == providerID
    else { return nil }
    return selectedList.listID
  }
}
