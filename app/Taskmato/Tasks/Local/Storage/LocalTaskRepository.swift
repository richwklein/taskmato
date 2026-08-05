//
//  LocalTaskRepository.swift
//  Taskmato
//

import Foundation

/// A minimal persistence conduit for the local task store: the full store in, the full store out.
///
/// Conformers own storage only. List/task manipulation, default-list invariants, and soft-delete
/// semantics all live in ``LocalProvider``, never here — the protocol deliberately exposes just
/// two requirements, mirroring ``SessionRepository``.
protocol LocalTaskRepository: Sendable {

  /// Loads the persisted store, or an empty store if nothing has been saved yet.
  func loadAll() async throws -> LocalStore

  /// Persists `store`, replacing any existing content.
  /// - Parameter store: The full local task store to write.
  func save(_ store: LocalStore) async throws
}

/// Top-level container for the local task store: lists, tasks, and the default list ID.
nonisolated struct LocalStore: Codable, Sendable {

  /// Lists managed by the provider, in creation order.
  var lists: [LocalList]

  /// All tasks, both active and soft-deleted (completed).
  var tasks: [LocalTask]

  /// The ID of the list new tasks are added to by default.
  var defaultListID: String?
}
