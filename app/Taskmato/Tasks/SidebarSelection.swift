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
}
