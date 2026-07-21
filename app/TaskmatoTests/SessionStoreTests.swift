//
//  SessionStoreTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

@MainActor
struct SessionStoreTests {

  /// Returns a facade backed by a repository on a unique temp file that won't affect
  /// production data. Disk persistence itself is covered by `JSONSessionRepositoryTests`;
  /// these tests exercise the observable mirror's synchronous optimistic-append path.
  private func makeStore() -> SessionStore {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString + ".json")
    return SessionStore(repository: JSONSessionRepository(fileURL: url))
  }

  private func makeSession(phase: SessionPhase = .focus, wasCompleted: Bool = true) -> Session {
    let start = Date(timeIntervalSinceReferenceDate: 0)
    return Session(
      id: UUID(), phase: phase, startedAt: start, endedAt: start.addingTimeInterval(1500),
      wasCompleted: wasCompleted)
  }

  @Test func appendIncreasesCount() {
    let store = makeStore()
    store.append(makeSession())
    #expect(store.sessions.count == 1)
  }

  @Test func appendedSessionIsRetrievable() {
    let store = makeStore()
    let session = makeSession(phase: .shortBreak)
    store.append(session)
    #expect(store.sessions.first?.id == session.id)
    #expect(store.sessions.first?.phase == .shortBreak)
  }

  @Test func multipleSessionsAreOrderedOldestFirst() {
    let store = makeStore()
    let first = makeSession(phase: .focus)
    let second = makeSession(phase: .shortBreak)
    store.append(first)
    store.append(second)
    #expect(store.sessions.first?.id == first.id)
    #expect(store.sessions.last?.id == second.id)
  }

}
