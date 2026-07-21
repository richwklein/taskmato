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
}
