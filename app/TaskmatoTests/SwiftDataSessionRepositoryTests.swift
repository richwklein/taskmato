//
//  SwiftDataSessionRepositoryTests.swift
//  TaskmatoTests
//

import Foundation
import SwiftData
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
    let segments: [FocusSegment] =
      phase == .focus
      ? [FocusSegment(id: UUID(), taskRef: taskRef, taskTitle: taskTitle, seconds: 1500)] : []
    return Session(
      id: UUID(), phase: phase, startedAt: startedAt,
      endedAt: startedAt.addingTimeInterval(1500), wasCompleted: true,
      segments: segments)
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
    #expect(session?.segments.first?.taskRef == ref)
    #expect(session?.segments.first?.taskTitle == "Write plan")
  }

  @Test func untrackedSessionHasNoTaskRef() async throws {
    let repository = try SwiftDataSessionRepository.makeInMemory()
    try await repository.append(makeSession(taskRef: nil, taskTitle: nil))
    let session = try await repository.sessions(over: Self.allTime).first
    #expect(session?.segments.count == 1)
    #expect(session?.segments.first?.taskRef == nil)
    #expect(session?.segments.first?.taskTitle == nil)
  }

  // MARK: - Provider cosmetics snapshot (ADR-0010, D4)

  @Test func upsertPreservesProviderCosmeticsSnapshot() async throws {
    let repository = try SwiftDataSessionRepository.makeInMemory()
    let id = UUID()
    let start = Date(timeIntervalSinceReferenceDate: 0)
    let ref = TaskRef(providerID: "obsidian", nativeID: "a")
    let session = Session(
      id: id, phase: .focus, startedAt: start, endedAt: start.addingTimeInterval(900),
      wasCompleted: true,
      segments: [
        FocusSegment(
          id: UUID(), taskRef: ref, taskTitle: "Task A", seconds: 900,
          providerLabel: "Obsidian", providerTint: .purple)
      ])
    try await repository.upsert(session)

    let sessions = try await repository.sessions(over: Self.allTime)
    #expect(sessions.first?.segments.first?.providerLabel == "Obsidian")
    #expect(sessions.first?.segments.first?.providerTint == .purple)
  }

  // MARK: - upsert (D7 of design doc 0010)

  @Test func upsertInsertsWhenIDIsNew() async throws {
    let repository = try SwiftDataSessionRepository.makeInMemory()
    let session = makeSession()
    try await repository.upsert(session)
    let sessions = try await repository.sessions(over: Self.allTime)
    #expect(sessions.count == 1)
    #expect(sessions.first?.id == session.id)
  }

  @Test func upsertReplacesAnExistingRowWithTheSameID() async throws {
    let repository = try SwiftDataSessionRepository.makeInMemory()
    let id = UUID()
    let start = Date(timeIntervalSinceReferenceDate: 0)
    let taskA = TaskRef(providerID: "local", nativeID: "a")
    let draft = Session(
      id: id, phase: .focus, startedAt: start, endedAt: start.addingTimeInterval(40),
      wasCompleted: false,
      segments: [FocusSegment(id: UUID(), taskRef: taskA, taskTitle: "Task A", seconds: 40)])
    try await repository.upsert(draft)

    let taskB = TaskRef(providerID: "local", nativeID: "b")
    let finalized = Session(
      id: id, phase: .focus, startedAt: start, endedAt: start.addingTimeInterval(60),
      wasCompleted: true,
      segments: [
        FocusSegment(id: UUID(), taskRef: taskA, taskTitle: "Task A", seconds: 40),
        FocusSegment(id: UUID(), taskRef: taskB, taskTitle: "Task B", seconds: 20),
      ])
    try await repository.upsert(finalized)

    let sessions = try await repository.sessions(over: Self.allTime)
    #expect(sessions.count == 1)
    #expect(sessions.first?.wasCompleted == true)
    #expect(sessions.first?.segments.count == 2)
  }

  @Test func upsertDoesNotDuplicateOtherRows() async throws {
    let repository = try SwiftDataSessionRepository.makeInMemory()
    let other = makeSession(startedAt: Date(timeIntervalSinceReferenceDate: 10_000))
    try await repository.append(other)

    let session = makeSession()
    try await repository.upsert(session)

    let sessions = try await repository.sessions(over: Self.allTime)
    #expect(sessions.count == 2)
  }

  // MARK: - Legacy backward-compatible read (D6 of design doc 0010)

  @Test func legacyEntityWithFlatFieldsDecodesToOneSlice() async throws {
    let container = try SwiftDataSessionRepository.makeInMemoryContainer()
    let repository = SwiftDataSessionRepository(modelContainer: container)
    let ref = TaskRef(providerID: "reminders", nativeID: "abc")
    let startedAt = Date(timeIntervalSinceReferenceDate: 0)
    let endedAt = startedAt.addingTimeInterval(1_500)
    let legacyEntity = SessionEntity(
      id: UUID(), phase: .focus, startedAt: startedAt, endedAt: endedAt, wasCompleted: true,
      segments: [], taskProviderID: ref.providerID.rawValue, taskNativeID: ref.nativeID,
      taskTitle: "Legacy task")
    let context = ModelContext(container)
    context.insert(legacyEntity)
    try context.save()

    let session = try await repository.sessions(over: Self.allTime).first
    #expect(session?.segments.count == 1)
    #expect(session?.segments.first?.taskRef == ref)
    #expect(session?.segments.first?.taskTitle == "Legacy task")
    #expect(session?.segments.first?.seconds == 1_500)
  }

  @Test func legacyEntityWithNoTaskDecodesToEmptySegments() async throws {
    let container = try SwiftDataSessionRepository.makeInMemoryContainer()
    let repository = SwiftDataSessionRepository(modelContainer: container)
    let startedAt = Date(timeIntervalSinceReferenceDate: 0)
    let legacyEntity = SessionEntity(
      id: UUID(), phase: .focus, startedAt: startedAt,
      endedAt: startedAt.addingTimeInterval(1_500), wasCompleted: true,
      segments: [], taskProviderID: nil, taskNativeID: nil, taskTitle: nil)
    let context = ModelContext(container)
    context.insert(legacyEntity)
    try context.save()

    let session = try await repository.sessions(over: Self.allTime).first
    #expect(session?.segments.isEmpty == true)
  }

  @Test func legacyBreakEntityWithStrayFlatFieldsDecodesToEmptySegments() async throws {
    let container = try SwiftDataSessionRepository.makeInMemoryContainer()
    let repository = SwiftDataSessionRepository(modelContainer: container)
    let startedAt = Date(timeIntervalSinceReferenceDate: 0)
    let legacyEntity = SessionEntity(
      id: UUID(), phase: .shortBreak, startedAt: startedAt,
      endedAt: startedAt.addingTimeInterval(300), wasCompleted: true,
      segments: [], taskProviderID: "local", taskNativeID: "abc", taskTitle: "Stray")
    let context = ModelContext(container)
    context.insert(legacyEntity)
    try context.save()

    let session = try await repository.sessions(over: Self.allTime).first
    #expect(session?.segments.isEmpty == true)
  }
}
