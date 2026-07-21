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
}
