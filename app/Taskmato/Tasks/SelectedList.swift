//
//  SelectedList.swift
//  Taskmato
//

import Foundation

/// Identifies a specific provider list by stable IDs.
struct SelectedList: Hashable, Codable, Sendable {

  /// The provider that owns this list.
  let providerID: String

  /// The list's stable identifier within its provider.
  let listID: String
}
