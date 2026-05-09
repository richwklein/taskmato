//
//  SessionStoreTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

struct SessionStoreTests {

  /// Returns a store backed by a unique temporary file that won't affect production data.
  private func makeStore() -> SessionStore {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString + ".json")
    return SessionStore(fileURL: url)
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

  @Test func sessionsRoundTripThroughDisk() throws {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString + ".json")

    let session = makeSession(phase: .focus)

    let writer = SessionStore(fileURL: url)
    writer.append(session)

    let reader = SessionStore(fileURL: url)
    #expect(reader.sessions.count == 1)
    #expect(reader.sessions.first?.id == session.id)
    #expect(reader.sessions.first?.phase == .focus)
  }

  @Test func sessionDurationIsEndMinusStart() {
    let start = Date(timeIntervalSinceReferenceDate: 0)
    let session = Session(
      id: UUID(), phase: .focus, startedAt: start, endedAt: start.addingTimeInterval(1500),
      wasCompleted: true)
    #expect(session.duration == 1500)
  }

}
