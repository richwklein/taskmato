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
    Session(
      id: UUID(),
      phase: .focus,
      startedAt: start,
      endedAt: start.addingTimeInterval(1500),
      wasCompleted: true,
      taskRef: taskRef
    )
  }

  @Test func sessionWithoutTaskRefRoundTrips() throws {
    let session = makeSession()
    let data = try JSONEncoder().encode(session)
    let decoded = try JSONDecoder().decode(Session.self, from: data)
    #expect(decoded.taskRef == nil)
    #expect(decoded.id == session.id)
  }

  @Test func sessionWithTaskRefRoundTrips() throws {
    let ref = TaskRef(providerID: "obsidian", nativeID: "vault/tasks.md:10")
    let session = makeSession(taskRef: ref)
    let data = try JSONEncoder().encode(session)
    let decoded = try JSONDecoder().decode(Session.self, from: data)
    #expect(decoded.taskRef == ref)
  }

  @Test func durationIsComputedFromTimestamps() {
    #expect(makeSession().duration == 1500)
  }
}
