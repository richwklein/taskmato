//
//  SessionStore.swift
//  Taskmato
//

import Foundation
import Observation

/// Observable, main-actor view facade over the session log.
///
/// Holds a published mirror of the recorded sessions for synchronous SwiftUI access and
/// delegates all persistence to an injected ``SessionRepository``. The authoritative cache
/// lives in the repository; all scope-shaping and aggregation now lives in ``StatsViewModel``.
@Observable
@MainActor
final class SessionStore {

  /// All recorded sessions, ordered oldest-first. A mirror of the repository's cache.
  private(set) var sessions: [Session] = []

  private let repository: SessionRepository

  /// Creates a store backed by the default JSON repository.
  convenience init() {
    self.init(repository: JSONSessionRepository(fileURL: JSONSessionRepository.defaultFileURL()))
  }

  /// Creates a store backed by a specific repository. Pass a fake or temporary-file
  /// repository in tests.
  init(repository: SessionRepository) {
    self.repository = repository
    Task { await reload() }
  }

  /// Appends a session record and persists it via the repository.
  func append(_ session: Session) {
    sessions.append(session)
    Task { try? await repository.append(session) }
  }

  /// Returns a ``SessionSummary`` for sessions whose `startedAt` falls within `interval`.
  /// - Parameter interval: The date range to scope results to.
  func summary(for interval: DateInterval) -> SessionSummary {
    SessionSummary(sessions: sessions, over: interval)
  }

  // MARK: - Private

  /// Refreshes the observable mirror from the repository's full log.
  private func reload() async {
    let all = try? await repository.sessions(
      over: DateInterval(start: .distantPast, end: .distantFuture))
    sessions = all ?? []
  }
}
