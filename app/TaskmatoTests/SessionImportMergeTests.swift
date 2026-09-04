//
//  SessionImportMergeTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

@Suite("Session import merge")
struct SessionImportMergeTests {

  private static let allTime = DateInterval(start: .distantPast, end: .distantFuture)

  @Test func mergeInsertsUpdatesSkipsAndRetainsEqualTimeConflicts() async throws {
    let repository = try SwiftDataSessionRepository.makeInMemory()
    let start = Date(timeIntervalSince1970: 100)
    let updateID = UUID()
    let skipID = UUID()
    let conflictID = UUID()
    try await repository.append(session(id: updateID, start: start, duration: 10, completed: false))
    try await repository.append(session(id: skipID, start: start, duration: 20, completed: true))
    try await repository.append(
      session(id: conflictID, start: start, duration: 30, completed: true))

    let result = try await repository.mergeImportedAtomically([
      session(id: UUID(), start: start, duration: 15, completed: true),
      session(id: updateID, start: start, duration: 40, completed: true),
      session(id: skipID, start: start, duration: 5, completed: false),
      session(id: conflictID, start: start, duration: 30, completed: false),
    ])

    #expect(result.inserted == 1)
    #expect(result.updated == 1)
    #expect(result.skipped == 1)
    #expect(result.conflicts == 1)
    let stored = try await repository.sessions(over: Self.allTime)
    #expect(stored.count == 4)
    #expect(stored.first(where: { $0.id == updateID })?.wasCompleted == true)
    #expect(stored.first(where: { $0.id == conflictID })?.wasCompleted == true)
  }

  @Test func reimportingTheSameSessionsIsANoOp() async throws {
    let repository = try SwiftDataSessionRepository.makeInMemory()
    let value = session(
      id: UUID(), start: Date(timeIntervalSince1970: 0), duration: 60, completed: true)
    _ = try await repository.mergeImportedAtomically([value])
    let result = try await repository.mergeImportedAtomically([value])

    #expect(result.isNoOp)
    #expect(result.skipped == 1)
    #expect(try await repository.sessions(over: Self.allTime).count == 1)
  }

  @Test func finalizedFocusReplacesImportedDraftWhileBreaksStayIndependent() async throws {
    let repository = try SwiftDataSessionRepository.makeInMemory()
    let start = Date(timeIntervalSince1970: 100)
    let draftID = UUID()
    let draft = session(id: draftID, start: start, duration: 30, completed: false)
    let breakSession = Session(
      id: UUID(), phase: .shortBreak, startedAt: start, endedAt: start.addingTimeInterval(300),
      wasCompleted: true)
    _ = try await repository.mergeImportedAtomically([draft, breakSession])

    let finalized = session(id: draftID, start: start, duration: 1_500, completed: true)
    let result = try await repository.mergeImportedAtomically([finalized])
    let stored = try await repository.sessions(over: Self.allTime)

    #expect(result.updated == 1)
    #expect(stored.count == 2)
    #expect(stored.first(where: { $0.id == draftID })?.wasCompleted == true)
    #expect(stored.first(where: { $0.phase == .shortBreak })?.segments.isEmpty == true)
  }

  @Test func failedAtomicMergeRollsBackInsertsAndUpdates() async throws {
    let repository = try SwiftDataSessionRepository.makeInMemory()
    let start = Date(timeIntervalSince1970: 100)
    let existingID = UUID()
    let existing = session(id: existingID, start: start, duration: 30, completed: false)
    try await repository.append(existing)
    await repository.setPreSaveHook { throw SaveFailure.injected }

    await #expect(throws: SaveFailure.self) {
      try await repository.mergeImportedAtomically([
        session(id: existingID, start: start, duration: 60, completed: true),
        session(id: UUID(), start: start, duration: 15, completed: true),
      ])
    }
    await repository.setPreSaveHook(nil)

    let stored = try await repository.sessions(over: Self.allTime)
    #expect(stored.count == 1)
    #expect(stored.first?.id == existingID)
    #expect(stored.first?.wasCompleted == false)
    #expect(stored.first?.duration == 30)
  }

  @MainActor
  @Test func durableSnapshotWaitsForQueuedAppendAndSurfacesWriteFailures() async throws {
    let delayed = DelayedRepository()
    let store = SessionStore(repository: delayed)
    let value = session(
      id: UUID(), start: Date(timeIntervalSince1970: 0), duration: 60, completed: true)
    store.append(value)

    let snapshot = try await store.durableSnapshot()
    #expect(snapshot.map(\.id) == [value.id])
    #expect(store.pendingPersistenceCount == 0)

    let failing = FailingRepository()
    let failingStore = SessionStore(repository: failing)
    failingStore.append(value)
    await #expect(throws: SessionStoreError.self) {
      try await failingStore.durableSnapshot()
    }
  }

  private func session(id: UUID, start: Date, duration: TimeInterval, completed: Bool) -> Session {
    Session(
      id: id, phase: .focus, startedAt: start, endedAt: start.addingTimeInterval(duration),
      wasCompleted: completed)
  }
}

private enum SaveFailure: Error { case injected }

/// A repository whose append deliberately yields to prove the durable-store barrier waits for it.
private actor DelayedRepository: SessionRepository {

  private var stored: [Session] = []

  func sessions(over interval: DateInterval) async throws -> [Session] {
    stored.filter { interval.contains($0.startedAt) }
  }

  func append(_ session: Session) async throws {
    try await Task.sleep(nanoseconds: 10_000_000)
    stored.append(session)
  }

  func upsert(_ session: Session) async throws {
    if let index = stored.firstIndex(where: { $0.id == session.id }) {
      stored[index] = session
    } else {
      stored.append(session)
    }
  }

  func mergeImportedAtomically(_ sessions: [Session]) async throws -> SessionMergeResult {
    stored.append(contentsOf: sessions)
    return SessionMergeResult(inserted: sessions.count)
  }
}

/// A repository that fails append without mutating its stored history.
private actor FailingRepository: SessionRepository {

  private enum Failure: Error { case write }

  func sessions(over _: DateInterval) async throws -> [Session] { [] }

  func append(_: Session) async throws { throw Failure.write }

  func upsert(_: Session) async throws { throw Failure.write }

  func mergeImportedAtomically(_: [Session]) async throws -> SessionMergeResult {
    throw Failure.write
  }
}
