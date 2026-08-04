//
//  SessionTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

@Suite("Session")
struct SessionTests {

  private let start = Date(timeIntervalSinceReferenceDate: 0)

  private func makeSession(taskRef: TaskRef? = nil) -> Session {
    let segments: [FocusSegment] =
      taskRef.map { [FocusSegment(id: UUID(), taskRef: $0, taskTitle: nil, seconds: 1500)] } ?? []
    return Session(
      id: UUID(),
      phase: .focus,
      startedAt: start,
      endedAt: start.addingTimeInterval(1500),
      wasCompleted: true,
      segments: segments
    )
  }

  @Test func sessionWithoutTaskRefRoundTrips() throws {
    let session = makeSession()
    let data = try JSONEncoder().encode(session)
    let decoded = try JSONDecoder().decode(Session.self, from: data)
    #expect(decoded.segments.isEmpty)
    #expect(decoded.id == session.id)
  }

  @Test func sessionWithTaskRefRoundTrips() throws {
    let ref = TaskRef(providerID: "obsidian", nativeID: "vault/tasks.md:10")
    let session = makeSession(taskRef: ref)
    let data = try JSONEncoder().encode(session)
    let decoded = try JSONDecoder().decode(Session.self, from: data)
    #expect(decoded.segments.first?.taskRef == ref)
  }

  @Test func durationIsComputedFromTimestamps() {
    #expect(makeSession().duration == 1500)
  }
}
