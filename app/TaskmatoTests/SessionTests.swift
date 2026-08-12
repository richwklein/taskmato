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

  // MARK: - Provider cosmetics snapshot (ADR-0010, D4)

  @Test func focusSegmentRoundTripsProviderCosmetics() throws {
    let ref = TaskRef(providerID: "obsidian", nativeID: "vault/tasks.md:10")
    let segment = FocusSegment(
      id: UUID(), taskRef: ref, taskTitle: "Write plan", seconds: 900,
      providerLabel: "Obsidian", providerTint: .purple)
    let data = try JSONEncoder().encode(segment)
    let decoded = try JSONDecoder().decode(FocusSegment.self, from: data)
    #expect(decoded.providerLabel == "Obsidian")
    #expect(decoded.providerTint == .purple)
  }

  @Test func legacyFocusSegmentJSONWithoutCosmeticsDecodesWithNilFields() throws {
    let json = """
      {"id":"\(UUID().uuidString)","taskRef":null,"taskTitle":null,"seconds":900}
      """
    let data = Data(json.utf8)
    let decoded = try JSONDecoder().decode(FocusSegment.self, from: data)
    #expect(decoded.providerLabel == nil)
    #expect(decoded.providerTint == nil)
  }
}
