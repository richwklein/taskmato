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

  /// The most recent persistence error, retained until a later successful write clears it.
  private(set) var lastPersistenceError: (any Error)?

  /// The number of optimistic writes that have not yet finished in the repository.
  private(set) var pendingPersistenceCount = 0

  /// A monotonically increasing marker for changes to the local session-history mirror.
  private(set) var historyRevision = 0

  private let repository: SessionRepository
  private var initialLoadTask: Task<Void, Never>?
  private var persistenceTail: Task<Void, Never>?

  /// Creates a store backed by a specific repository. Pass a fake or in-memory
  /// repository in tests.
  init(repository: SessionRepository) {
    self.repository = repository
    initialLoadTask = Task { [weak self, repository] in
      do {
        let all = try await repository.sessions(
          over: DateInterval(start: .distantPast, end: .distantFuture))
        self?.sessions = all
      } catch {
        self?.lastPersistenceError = error
      }
    }
  }

  /// Appends a session record and persists it via the repository.
  func append(_ session: Session) {
    sessions.append(session)
    historyRevision += 1
    enqueuePersistence { repository in try await repository.append(session) }
  }

  /// Records a session, replacing any existing record with the same `id` in both the mirror
  /// and the repository (D7 of design doc 0010) — the durable phase draft's write path.
  func upsert(_ session: Session) {
    if let index = sessions.firstIndex(where: { $0.id == session.id }) {
      sessions[index] = session
    } else {
      sessions.append(session)
    }
    historyRevision += 1
    enqueuePersistence { repository in try await repository.upsert(session) }
  }

  /// Waits for initial loading and every preceding optimistic write, then reads durable history.
  /// - Returns: The repository-backed session log, oldest-first.
  func durableSnapshot() async throws -> [Session] {
    await initialLoadTask?.value
    let tail = persistenceTail
    await tail?.value
    if let lastPersistenceError {
      throw SessionStoreError.persistenceFailed(lastPersistenceError.localizedDescription)
    }
    return try await repository.sessions(
      over: DateInterval(start: .distantPast, end: .distantFuture))
  }

  /// Applies a prevalidated imported history merge, then refreshes the observable mirror.
  /// - Parameter sessions: The normalized sessions to merge.
  /// - Returns: The repository's insert, update, skip, and conflict counts.
  func mergeImportedAtomically(_ sessions: [Session]) async throws -> SessionMergeResult {
    _ = try await durableSnapshot()
    let result = try await repository.mergeImportedAtomically(sessions)
    self.sessions = try await repository.sessions(
      over: DateInterval(start: .distantPast, end: .distantFuture))
    historyRevision += 1
    return result
  }

  /// Returns a ``SessionSummary`` for sessions whose `startedAt` falls within `interval`.
  /// - Parameter interval: The date range to scope results to.
  func summary(for interval: DateInterval) -> SessionSummary {
    SessionSummary(sessions: sessions, over: interval)
  }

  /// Refreshes the observable mirror from the repository's full log.
  func reload() async {
    do {
      sessions = try await repository.sessions(
        over: DateInterval(start: .distantPast, end: .distantFuture))
    } catch {
      lastPersistenceError = error
    }
  }

  /// Adds one operation to the serial persistence queue and records its completion state.
  private func enqueuePersistence(
    _ operation: @escaping @Sendable (SessionRepository) async throws -> Void
  ) {
    let previous = persistenceTail
    let repository = repository
    pendingPersistenceCount += 1
    persistenceTail = Task { [weak self, repository] in
      await previous?.value
      do {
        try await operation(repository)
        self?.lastPersistenceError = nil
      } catch {
        self?.lastPersistenceError = error
      }
      self?.pendingPersistenceCount -= 1
    }
  }
}

/// An error surfaced when a durable session-history boundary includes a failed write.
enum SessionStoreError: LocalizedError, Sendable {

  /// A prior optimistic repository write failed before the requested durable boundary.
  case persistenceFailed(String)

  /// A human-readable persistence failure description.
  var errorDescription: String? {
    switch self {
    case .persistenceFailed(let message): return "Session history could not be saved: \(message)"
    }
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
