//
//  SwiftDataSessionRepositoryTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

@Suite("SwiftDataSessionRepository")
struct SwiftDataSessionRepositoryTests {

  private static let allTime = DateInterval(start: .distantPast, end: .distantFuture)

  private func makeSession(
    phase: SessionPhase = .focus,
    startedAt: Date = Date(timeIntervalSinceReferenceDate: 0),
    taskRef: TaskRef? = nil, taskTitle: String? = nil
  ) -> Session {
    Session(
      id: UUID(), phase: phase, startedAt: startedAt,
      endedAt: startedAt.addingTimeInterval(1500), wasCompleted: true,
      taskRef: taskRef, taskTitle: taskTitle)
  }

  @Test func appendedSessionIsReturned() async throws {
    let repository = try SwiftDataSessionRepository.makeInMemory()
    let session = makeSession(phase: .shortBreak)
    try await repository.append(session)
    let sessions = try await repository.sessions(over: Self.allTime)
    #expect(sessions.count == 1)
    #expect(sessions.first?.id == session.id)
    #expect(sessions.first?.phase == .shortBreak)
  }

  @Test func sessionsAreOrderedOldestFirst() async throws {
    let repository = try SwiftDataSessionRepository.makeInMemory()
    let first = makeSession(startedAt: Date(timeIntervalSinceReferenceDate: 0))
    let second = makeSession(startedAt: Date(timeIntervalSinceReferenceDate: 10_000))
    try await repository.append(second)  // insert out of order on purpose
    try await repository.append(first)
    let sessions = try await repository.sessions(over: Self.allTime)
    #expect(sessions.first?.id == first.id)
    #expect(sessions.last?.id == second.id)
  }

  @Test func sessionsOutsideIntervalAreExcluded() async throws {
    let repository = try SwiftDataSessionRepository.makeInMemory()
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

  @Test func taskRefAndTitleRoundTrip() async throws {
    let repository = try SwiftDataSessionRepository.makeInMemory()
    let ref = TaskRef(providerID: "reminders", nativeID: "abc")
    try await repository.append(makeSession(taskRef: ref, taskTitle: "Write plan"))
    let session = try await repository.sessions(over: Self.allTime).first
    #expect(session?.taskRef == ref)
    #expect(session?.taskTitle == "Write plan")
  }

  @Test func untrackedSessionHasNoTaskRef() async throws {
    let repository = try SwiftDataSessionRepository.makeInMemory()
    try await repository.append(makeSession(taskRef: nil, taskTitle: nil))
    let session = try await repository.sessions(over: Self.allTime).first
    #expect(session?.taskRef == nil)
    #expect(session?.taskTitle == nil)
  }
}
