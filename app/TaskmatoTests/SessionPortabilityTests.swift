//
//  SessionPortabilityTests.swift
//  TaskmatoTests
//

import Foundation
import Testing
import UniformTypeIdentifiers

@testable import Taskmato

@Suite("Session portability")
struct SessionPortabilityTests {

  @Test func sessionHistoryFileUsesTheStandardJSONContentType() {
    #expect(SessionHistoryFile.readableContentTypes == [.json])
  }

  @Test func goldenV1FixtureDecodesAndReencodesOnlyPortableFields() throws {
    let data = try fixtureData()
    let payload = try SessionPortability.decodeAndNormalize(data)

    #expect(payload.sessions.count == 1)
    #expect(payload.sessions.first?.segments.first?.taskTitle == "Write portability tests")

    let document = try SessionPortability.makeDocument(
      sessions: payload.sessions,
      exportedAt: Date(timeIntervalSince1970: 1_788_544_800))
    let encoded = try SessionPortability.encode(document)
    let object = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]
    let keys: Set<String> = object.map { Set($0.keys) } ?? []
    #expect(keys == ["schemaVersion", "exportedAt", "sessions"])
    #expect(!(String(bytes: encoded, encoding: .utf8) ?? "").contains("credentials"))
  }

  @Test func recordsSortByStartEndThenIdentifier() throws {
    let start = Date(timeIntervalSince1970: 100)
    let later = Session(
      id: UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")!, phase: .focus,
      startedAt: start, endedAt: start.addingTimeInterval(10), wasCompleted: false)
    let earlierEnd = Session(
      id: UUID(uuidString: "EEEEEEEE-EEEE-EEEE-EEEE-EEEEEEEEEEEE")!, phase: .focus,
      startedAt: start, endedAt: start.addingTimeInterval(5), wasCompleted: false)

    let document = try SessionPortability.makeDocument(
      sessions: [later, earlierEnd], exportedAt: start)
    #expect(document.sessions.map(\.id) == [earlierEnd.id, later.id])
    #expect(document.exportedAt.contains(".000Z"))
  }

  @Test func unsupportedVersionAndBreakSegmentsAreRejected() throws {
    let document = SessionHistoryDocumentV1(
      schemaVersion: 2, exportedAt: "2026-09-04T18:00:00.000Z", sessions: [])
    #expect(throws: SessionPortabilityError.self) {
      try SessionPortability.decodeAndNormalize(document)
    }

    let invalid = SessionHistoryDocumentV1(
      schemaVersion: 1, exportedAt: "2026-09-04T18:00:00.000Z",
      sessions: [
        SessionRecordV1(
          id: UUID(), phase: "shortBreak", startedAt: "2026-09-04T18:00:00.000Z",
          endedAt: "2026-09-04T18:05:00.000Z", wasCompleted: true,
          segments: [
            FocusSegmentV1(
              id: UUID(), taskRef: nil, taskTitle: nil, seconds: 1, providerLabel: nil,
              providerTint: nil)
          ])
      ])
    #expect(throws: SessionPortabilityError.self) {
      try SessionPortability.decodeAndNormalize(invalid)
    }
  }

  @Test func duplicateHighestEndCandidatesNormalizeOrRejectDivergence() throws {
    let fixture = try fixtureRecord()
    let duplicate = SessionHistoryDocumentV1(
      schemaVersion: 1, exportedAt: "2026-09-04T18:00:00.000Z", sessions: [fixture, fixture])
    #expect(try SessionPortability.decodeAndNormalize(duplicate).duplicateSkips == 1)

    let divergent = SessionRecordV1(
      id: fixture.id, phase: fixture.phase, startedAt: fixture.startedAt, endedAt: fixture.endedAt,
      wasCompleted: false, segments: fixture.segments)
    let invalid = SessionHistoryDocumentV1(
      schemaVersion: 1, exportedAt: "2026-09-04T18:00:00.000Z", sessions: [fixture, divergent])
    #expect(throws: SessionPortabilityError.self) {
      try SessionPortability.decodeAndNormalize(invalid)
    }
  }

  @Test func rejectsEveryConfiguredCountAndTextLimitAtOneOver() throws {
    let fixture = try fixtureRecord()
    let envelope = "2026-09-04T18:00:00.000Z"
    #expect(throws: SessionPortabilityError.self) {
      try SessionPortability.decodeAndNormalize(Data(repeating: 0, count: 10 * 1_024 * 1_024 + 1))
    }
    #expect(throws: SessionPortabilityError.self) {
      try SessionPortability.decodeAndNormalize(
        SessionHistoryDocumentV1(
          schemaVersion: 1, exportedAt: envelope,
          sessions: Array(repeating: fixture, count: SessionPortability.maximumSessions + 1)))
    }

    let segment = fixture.segments[0]
    let manySegments = (0...SessionPortability.maximumSegmentsPerSession).map { _ in
      FocusSegmentV1(
        id: UUID(), taskRef: nil, taskTitle: nil, seconds: 1, providerLabel: nil,
        providerTint: nil)
    }
    #expect(throws: SessionPortabilityError.self) {
      try SessionPortability.decodeAndNormalize(document(records: [record(segments: manySegments)]))
    }
    let totalSegments = (0...390).map { _ in
      record(
        segments: Array(repeating: segment, count: SessionPortability.maximumSegmentsPerSession))
    }
    #expect(throws: SessionPortabilityError.self) {
      try SessionPortability.decodeAndNormalize(document(records: totalSegments))
    }
    for oversized in [
      FocusSegmentV1(
        id: UUID(),
        taskRef: TaskRefV1(providerID: String(repeating: "p", count: 257), nativeID: "n"),
        taskTitle: nil, seconds: 1, providerLabel: nil, providerTint: nil),
      FocusSegmentV1(
        id: UUID(),
        taskRef: TaskRefV1(
          providerID: "p", nativeID: String(repeating: "n", count: 16 * 1_024 + 1)),
        taskTitle: nil, seconds: 1, providerLabel: nil, providerTint: nil),
      FocusSegmentV1(
        id: UUID(), taskRef: nil, taskTitle: String(repeating: "t", count: 16 * 1_024 + 1),
        seconds: 1, providerLabel: nil, providerTint: nil),
      FocusSegmentV1(
        id: UUID(), taskRef: nil, taskTitle: nil, seconds: 1,
        providerLabel: String(repeating: "l", count: 1_024 + 1), providerTint: nil),
    ] {
      #expect(throws: SessionPortabilityError.self) {
        try SessionPortability.decodeAndNormalize(
          document(records: [record(segments: [oversized])]))
      }
    }
  }

  @Test func rejectsCombinedTextOverFourMiB() throws {
    let maximumTitle = String(repeating: "t", count: 16 * 1_024)
    let combinedText = [128, 128, 1].map { count in
      record(
        segments: (0..<count).map { _ in
          FocusSegmentV1(
            id: UUID(), taskRef: nil, taskTitle: maximumTitle, seconds: 1, providerLabel: nil,
            providerTint: nil)
        })
    }
    #expect(throws: SessionPortabilityError.self) {
      try SessionPortability.decodeAndNormalize(document(records: combinedText))
    }
  }

  @Test func rejectsMalformedDatesAndSegmentInvariants() throws {
    let base = try fixtureRecord()
    let invalidDates = SessionRecordV1(
      id: base.id, phase: base.phase, startedAt: base.endedAt, endedAt: base.startedAt,
      wasCompleted: base.wasCompleted, segments: base.segments)
    let invalidSeconds = FocusSegmentV1(
      id: UUID(), taskRef: nil, taskTitle: nil, seconds: .infinity, providerLabel: nil,
      providerTint: nil)
    let duplicateID = UUID()
    let duplicateSegments = [
      FocusSegmentV1(
        id: duplicateID, taskRef: nil, taskTitle: nil, seconds: 1, providerLabel: nil,
        providerTint: nil),
      FocusSegmentV1(
        id: duplicateID, taskRef: nil, taskTitle: nil, seconds: 1, providerLabel: nil,
        providerTint: nil),
    ]
    let excessive = FocusSegmentV1(
      id: UUID(), taskRef: nil, taskTitle: nil, seconds: 1_501, providerLabel: nil,
      providerTint: nil)
    for invalid in [
      invalidDates,
      record(segments: [invalidSeconds]),
      record(segments: duplicateSegments),
      record(segments: [excessive]),
    ] {
      #expect(throws: SessionPortabilityError.self) {
        try SessionPortability.decodeAndNormalize(document(records: [invalid]))
      }
    }
  }

  private func fixtureData() throws -> Data {
    try Data(contentsOf: fixtureURL())
  }

  private func fixtureRecord() throws -> SessionRecordV1 {
    try JSONDecoder().decode(SessionHistoryDocumentV1.self, from: fixtureData()).sessions[0]
  }

  private func record(segments: [FocusSegmentV1]) -> SessionRecordV1 {
    SessionRecordV1(
      id: UUID(), phase: "focus", startedAt: "2026-09-04T18:00:00.000Z",
      endedAt: "2026-09-04T18:25:00.000Z", wasCompleted: true, segments: segments)
  }

  private func document(records: [SessionRecordV1]) -> SessionHistoryDocumentV1 {
    SessionHistoryDocumentV1(
      schemaVersion: 1, exportedAt: "2026-09-04T18:30:00.000Z", sessions: records)
  }

  private func fixtureURL() -> URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .appendingPathComponent("Fixtures/session-history-v1.json")
  }
}
