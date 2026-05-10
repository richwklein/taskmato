//
//  LocalList.swift
//  Taskmato
//

import Foundation

/// A named grouping of tasks managed by ``LocalProvider``.
struct LocalList: Codable, Identifiable, Hashable {

  /// Stable unique identifier for this list.
  let id: UUID

  /// User-visible name shown in the task picker and add-task sheet.
  var name: String

  /// Returns this list expressed as the provider-agnostic ``TaskList`` type.
  var asTaskList: TaskList {
    TaskList(id: id.uuidString, providerID: LocalProvider.providerID, name: name)
  }
}
