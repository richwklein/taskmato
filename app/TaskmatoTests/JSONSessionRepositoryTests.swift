//
//  JSONSessionRepositoryTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

@Suite("JSONSessionRepository")
struct JSONSessionRepositoryTests {

  private static let allTime = DateInterval(start: .distantPast, end: .distantFuture)

  /// Returns a unique temporary file URL that won't affect production data.
  private func makeTempURL() -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString + ".json")
  }

  private func makeSession(
    phase: SessionPhase = .focus,
    startedAt: Date = Date(timeIntervalSinceReferenceDate: 0),
    wasCompleted: Bool = true
  ) -> Session {
    Session(
      id: UUID(), phase: phase, startedAt: startedAt,
      endedAt: startedAt.addingTimeInterval(1500), wasCompleted: wasCompleted)
  }

  @Test func appendedSessionIsReturned() async throws {
    let repository = JSONSessionRepository(fileURL: makeTempURL())
    let session = makeSession(phase: .shortBreak)
    try await repository.append(session)
    let sessions = try await repository.sessions(over: Self.allTime)
    #expect(sessions.count == 1)
    #expect(sessions.first?.id == session.id)
    #expect(sessions.first?.phase == .shortBreak)
  }

  @Test func sessionsPersistAcrossInstances() async throws {
    let url = makeTempURL()
    let session = makeSession()

    let writer = JSONSessionRepository(fileURL: url)
    try await writer.append(session)

    let reader = JSONSessionRepository(fileURL: url)
    let sessions = try await reader.sessions(over: Self.allTime)
    #expect(sessions.count == 1)
    #expect(sessions.first?.id == session.id)
  }

  @Test func sessionsAreOrderedOldestFirst() async throws {
    let repository = JSONSessionRepository(fileURL: makeTempURL())
    let first = makeSession(phase: .focus)
    let second = makeSession(phase: .shortBreak)
    try await repository.append(first)
    try await repository.append(second)
    let sessions = try await repository.sessions(over: Self.allTime)
    #expect(sessions.first?.id == first.id)
    #expect(sessions.last?.id == second.id)
  }

  @Test func sessionsOutsideIntervalAreExcluded() async throws {
    let repository = JSONSessionRepository(fileURL: makeTempURL())
    let reference = Date(timeIntervalSinceReferenceDate: 1_000_000)
    let inside = makeSession(startedAt: reference)
    let outside = makeSession(startedAt: reference.addingTimeInterval(-10_000))
    try await repository.append(inside)
    try await repository.append(outside)

    let interval = DateInterval(
      start: reference.addingTimeInterval(-60), end: reference.addingTimeInterval(60))
    let sessions = try await repository.sessions(over: interval)
    #expect(sessions.count == 1)
    #expect(sessions.first?.id == inside.id)
  }

  @Test func appendThrowsWhenPathIsUnwritable() async throws {
    let unwritable = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
      .appendingPathComponent("does-not-exist")
      .appendingPathComponent("sessions.json")
    let repository = JSONSessionRepository(fileURL: unwritable)
    await #expect(throws: (any Error).self) {
      try await repository.append(makeSession())
    }
  }
}
