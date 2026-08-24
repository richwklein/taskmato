//
//  DefaultListResolver.swift
//  Taskmato
//

import Foundation

/// Chooses which list a picker or new-task form should select from a provider's available lists.
enum DefaultListResolver {

  /// Returns the stored default when it is among `lists`, otherwise the first available list,
  /// or `nil` when no lists are available.
  static func resolve(among lists: [TaskList], storedDefault: String?) -> String? {
    if let storedDefault, lists.contains(where: { $0.id == storedDefault }) {
      return storedDefault
    }
    return lists.first?.id
  }
}
