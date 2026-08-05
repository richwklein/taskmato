//
//  LocalListEntity.swift
//  Taskmato
//

import Foundation
import SwiftData

/// The SwiftData persistence record mirroring a ``LocalList``'s stored fields.
///
/// `isDefault` encodes ``LocalStore/defaultListID`` (a `String?` uuidString with no natural
/// entity home) as a flag on the list entity itself, keeping to the two-entity model.
@Model
final class LocalListEntity {

  /// Stable unique identifier and the record's identity.
  @Attribute(.unique) var id: UUID

  /// User-visible name shown in the task picker and add-task sheet.
  var name: String

  /// Wall-clock time when this list was first created; the stored ordering key.
  var createdAt: Date

  /// `true` when this list is the provider's current default target for new tasks.
  var isDefault: Bool

  /// Creates a persistence record from explicit field values.
  init(id: UUID, name: String, createdAt: Date, isDefault: Bool) {
    self.id = id
    self.name = name
    self.createdAt = createdAt
    self.isDefault = isDefault
  }
}

extension LocalListEntity {

  /// Creates a persistence record from a domain ``LocalList``.
  /// - Parameters:
  ///   - list: The list to copy fields from.
  ///   - isDefault: Whether `list` is the provider's current default list.
  convenience init(list: LocalList, isDefault: Bool) {
    self.init(id: list.id, name: list.name, createdAt: list.createdAt, isDefault: isDefault)
  }

  /// Updates this record's fields in place from a domain ``LocalList``, keeping its identity —
  /// the mutate branch of ``SwiftDataLocalTaskRepository/save(_:)``.
  /// - Parameters:
  ///   - list: The list to copy fields from.
  ///   - isDefault: Whether `list` is the provider's current default list.
  func update(from list: LocalList, isDefault: Bool) {
    name = list.name
    createdAt = list.createdAt
    self.isDefault = isDefault
  }
}

extension LocalList {

  /// Reconstructs a domain ``LocalList`` from its persistence record.
  nonisolated init(entity: LocalListEntity) {
    self.init(id: entity.id, name: entity.name, createdAt: entity.createdAt)
  }
}
