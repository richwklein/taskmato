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

  /// Creates a store backed by a specific repository. Pass a fake or in-memory
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

  /// Records a session, replacing any existing record with the same `id` in both the mirror
  /// and the repository (D7 of design doc 0010) — the durable phase draft's write path.
  func upsert(_ session: Session) {
    if let index = sessions.firstIndex(where: { $0.id == session.id }) {
      sessions[index] = session
    } else {
      sessions.append(session)
    }
    Task { try? await repository.upsert(session) }
  }

  /// Returns a ``SessionSummary`` for sessions whose `startedAt` falls within `interval`.
  /// - Parameter interval: The date range to scope results to.
  func summary(for interval: DateInterval) -> SessionSummary {
    SessionSummary(sessions: sessions, over: interval)
  }

  /// Refreshes the observable mirror from the repository's full log.
  func reload() async {
    let all = try? await repository.sessions(
      over: DateInterval(start: .distantPast, end: .distantFuture))
    sessions = all ?? []
  }
}

#if DEBUG
  extension SessionStore {

    /// A store backed by a fresh in-memory repository, synchronously seeded with `sessions`.
    ///
    /// For SwiftUI previews, where waiting on the async `reload()` would leave the preview
    /// briefly empty.
    /// - Parameter sessions: The sessions to seed the observable mirror with.
    static func seeded(_ sessions: [Session]) -> SessionStore {
      guard let repository = try? SwiftDataSessionRepository.makeInMemory() else {
        fatalError("Failed to build in-memory preview repository")
      }
      let store = SessionStore(repository: repository)
      store.sessions = sessions
      return store
    }
  }
#endif
