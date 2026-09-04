//
//  FakeSessionRepository.swift
//  TaskmatoTests
//

import Foundation

@testable import Taskmato

/// In-memory ``SessionRepository`` seeded with fixed sessions, shared across consumer-facing suites.
@MainActor
final class FakeSessionRepository: SessionRepository {

  private var stored: [Session]

  init(sessions: [Session] = []) { self.stored = sessions }

  func sessions(over interval: DateInterval) async throws -> [Session] {
    stored.filter { interval.contains($0.startedAt) }
  }

  func append(_ session: Session) async throws { stored.append(session) }

  func upsert(_ session: Session) async throws {
    if let index = stored.firstIndex(where: { $0.id == session.id }) {
      stored[index] = session
    } else {
      stored.append(session)
    }
  }

  func mergeImportedAtomically(_ sessions: [Session]) async throws -> SessionMergeResult {
    var proposed = stored
    var result = SessionMergeResult()
    for session in sessions {
      if let index = proposed.firstIndex(where: { $0.id == session.id }) {
        let local = proposed[index]
        if session.endedAt > local.endedAt {
          proposed[index] = session
          result.updated += 1
        } else if session.endedAt < local.endedAt || session == local {
          result.skipped += 1
        } else {
          result.conflicts += 1
        }
      } else {
        proposed.append(session)
        result.inserted += 1
      }
    }
    stored = proposed
    return result
  }
}
