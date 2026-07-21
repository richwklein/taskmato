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
/// lives in the repository; this facade's aggregation helpers move to the stats view model
/// as the storage layer evolves.
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

  /// Returns a summary scoped to the current calendar day (local time zone).
  func todaySummary() -> SessionSummary {
    let calendar = Calendar.current
    let start = calendar.startOfDay(for: Date())
    let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
    return summary(for: DateInterval(start: start, end: end))
  }

  /// Returns a summary scoped to a rolling seven-day window ending now.
  func thisWeekSummary() -> SessionSummary {
    let calendar = Calendar.current
    let todayStart = calendar.startOfDay(for: Date())
    let start = calendar.date(byAdding: .day, value: -6, to: todayStart) ?? todayStart
    return summary(for: DateInterval(start: start, end: Date()))
  }

  /// Number of completed focus sessions that started today (calendar day, local time zone).
  func todayFocusCount() -> Int {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    return sessions.filter {
      $0.phase == .focus && $0.wasCompleted && calendar.startOfDay(for: $0.startedAt) == today
    }.count
  }

  /// Total elapsed minutes across all completed focus sessions that started today.
  func todayFocusMinutes() -> Int {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let total = sessions.filter {
      $0.phase == .focus && $0.wasCompleted && calendar.startOfDay(for: $0.startedAt) == today
    }.reduce(0) { $0 + $1.duration }
    return Int(total / 60)
  }

  // MARK: - Private

  /// Refreshes the observable mirror from the repository's full log.
  private func reload() async {
    let all = try? await repository.sessions(
      over: DateInterval(start: .distantPast, end: .distantFuture))
    sessions = all ?? []
  }
}
