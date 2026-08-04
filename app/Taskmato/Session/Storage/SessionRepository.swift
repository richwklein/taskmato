//
//  SessionRepository.swift
//  Taskmato
//

import Foundation

/// A minimal persistence conduit for the session log: raw sessions in, raw sessions out.
///
/// Conformers own storage only. All grouping, counting, and streak logic lives in the
/// stats view model, never here — the protocol deliberately exposes just two requirements.
protocol SessionRepository: Sendable {

  /// Returns the recorded sessions whose `startedAt` falls within `interval`, oldest-first.
  /// - Parameter interval: The date range to scope results to.
  func sessions(over interval: DateInterval) async throws -> [Session]

  /// Persists a session record to the log.
  /// - Parameter session: The completed session to append.
  func append(_ session: Session) async throws

  /// Persists a session record, replacing any existing record with the same `id`.
  ///
  /// Backs the durable phase draft (D7 of design doc 0010): a mid-phase slice close upserts the
  /// in-progress record, and the final write at phase end upserts over it.
  /// - Parameter session: The session to insert or update.
  func upsert(_ session: Session) async throws
}
