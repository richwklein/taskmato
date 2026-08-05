//
//  LocalList.swift
//  Taskmato
//

import Foundation

/// A named grouping of tasks managed by ``LocalProvider``.
nonisolated struct LocalList: Codable, Identifiable, Hashable, Sendable {

  /// Stable unique identifier for this list.
  let id: UUID

  /// User-visible name shown in the task picker and add-task sheet.
  var name: String

  /// Wall-clock time when this list was first created; the stored ordering key.
  let createdAt: Date

  private nonisolated enum CodingKeys: String, CodingKey {
    case id, name, createdAt
  }

  /// Returns this list expressed as the provider-agnostic ``TaskList`` type.
  var asTaskList: TaskList {
    TaskList(id: id.uuidString, providerID: LocalProvider.providerID, name: name)
  }
}

extension LocalList {

  /// Decodes a ``LocalList`` from `decoder`, defaulting `createdAt` to `.distantPast` when
  /// absent.
  ///
  /// The default preserves backward compatibility with JSON records written before the
  /// `createdAt` field was introduced; ``LocalStoreJSONMigrator`` overrides it with
  /// order-preserving synthesized timestamps during the one-shot migration.
  nonisolated init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(UUID.self, forKey: .id)
    name = try container.decode(String.self, forKey: .name)
    createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? .distantPast
  }
}
