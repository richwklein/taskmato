//
//  SessionStoreTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

@MainActor
struct SessionStoreTests {

  /// Returns a facade backed by an in-memory fake repository. Persistence itself is covered by
  /// `SwiftDataSessionRepositoryTests`; these tests exercise the observable mirror's synchronous
  /// optimistic-append path.
  private func makeStore() -> SessionStore {
    SessionStore(repository: FakeSessionRepository())
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

  // MARK: - upsert (D7 of design doc 0010)

  @Test func upsertInsertsWhenIDIsNew() {
    let store = makeStore()
    let session = makeSession()
    store.upsert(session)
    #expect(store.sessions.count == 1)
    #expect(store.sessions.first?.id == session.id)
  }

  @Test func upsertReplacesAnExistingRecordWithTheSameID() {
    let store = makeStore()
    let id = UUID()
    let start = Date(timeIntervalSinceReferenceDate: 0)
    let draft = Session(
      id: id, phase: .focus, startedAt: start, endedAt: start.addingTimeInterval(40),
      wasCompleted: false)
    store.upsert(draft)
    #expect(store.sessions.count == 1)

    let finalized = Session(
      id: id, phase: .focus, startedAt: start, endedAt: start.addingTimeInterval(1_500),
      wasCompleted: true)
    store.upsert(finalized)

    #expect(store.sessions.count == 1)
    #expect(store.sessions.first?.wasCompleted == true)
    #expect(store.sessions.first?.duration == 1_500)
  }

  @Test func upsertPreservesOrderOfOtherSessions() {
    let store = makeStore()
    let first = makeSession(phase: .focus)
    let second = makeSession(phase: .shortBreak)
    store.append(first)
    store.append(second)

    let updatedFirst = Session(
      id: first.id, phase: first.phase, startedAt: first.startedAt, endedAt: first.endedAt,
      wasCompleted: true)
    store.upsert(updatedFirst)

    #expect(store.sessions.count == 2)
    #expect(store.sessions.first?.id == first.id)
    #expect(store.sessions.last?.id == second.id)
  }

}
