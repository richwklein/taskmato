//
//  SessionPortability.swift
//  Taskmato
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// The versioned, privacy-bounded document used for manual session-history portability.
nonisolated struct SessionHistoryDocumentV1: Codable, Sendable, Equatable {

  /// The only schema version understood by this build.
  let schemaVersion: Int

  /// The UTC time when this document was produced.
  let exportedAt: String

  /// The complete persisted session-history snapshot.
  let sessions: [SessionRecordV1]

  /// Keeps the V1 wire names independent from domain-model property changes.
  enum CodingKeys: String, CodingKey {
    /// The document compatibility version.
    case schemaVersion
    /// The UTC export timestamp.
    case exportedAt
    /// The exported session rows.
    case sessions
  }
}

/// The frozen V1 representation of one persisted session row.
nonisolated struct SessionRecordV1: Codable, Sendable, Equatable {

  /// The stable session identifier.
  let id: UUID
  /// The persisted phase raw value.
  let phase: String
  /// The fixed RFC 3339 UTC start timestamp.
  let startedAt: String
  /// The fixed RFC 3339 UTC end timestamp.
  let endedAt: String
  /// Whether the timer naturally completed the phase.
  let wasCompleted: Bool
  /// The focus attribution captured within this session.
  let segments: [FocusSegmentV1]

  /// Keeps the V1 wire names independent from domain-model property changes.
  enum CodingKeys: String, CodingKey {
    /// The session identifier.
    case id
    /// The phase string.
    case phase
    /// The start timestamp.
    case startedAt
    /// The end timestamp.
    case endedAt
    /// The natural-completion flag.
    case wasCompleted
    /// The focus-segment rows.
    case segments
  }
}

/// The frozen V1 representation of one focus-attribution slice.
nonisolated struct FocusSegmentV1: Codable, Sendable, Equatable {

  /// The stable segment identifier.
  let id: UUID
  /// The optional portable task identity.
  let taskRef: TaskRefV1?
  /// The task-title snapshot, if available.
  let taskTitle: String?
  /// The positive focus duration in seconds.
  let seconds: TimeInterval
  /// The provider-label snapshot, if available.
  let providerLabel: String?
  /// The provider-tint snapshot, if available.
  let providerTint: ProviderTint?

  /// Keeps the V1 wire names independent from domain-model property changes.
  enum CodingKeys: String, CodingKey {
    /// The segment identifier.
    case id
    /// The task identity.
    case taskRef
    /// The task-title snapshot.
    case taskTitle
    /// The duration in seconds.
    case seconds
    /// The provider-label snapshot.
    case providerLabel
    /// The provider-tint snapshot.
    case providerTint
  }
}

/// The frozen V1 task identifier used inside a portable focus segment.
nonisolated struct TaskRefV1: Codable, Sendable, Equatable {

  /// The stable Taskmato provider identifier.
  let providerID: String
  /// The provider-owned task identifier.
  let nativeID: String

  /// Keeps the V1 wire names independent from domain-model property changes.
  enum CodingKeys: String, CodingKey {
    /// The provider identifier.
    case providerID
    /// The provider-native task identifier.
    case nativeID
  }
}

/// Insert, update, skip, and conflict totals for an import merge.
nonisolated struct SessionMergeResult: Sendable, Equatable {

  /// The number of incoming rows newly stored.
  var inserted: Int = 0
  /// The number of local rows replaced by a later incoming row.
  var updated: Int = 0
  /// The number of incoming rows retained only as a no-op or older duplicate.
  var skipped: Int = 0
  /// The number of equal-time divergent local rows retained unchanged.
  var conflicts: Int = 0

  /// Whether this result changed no persisted row.
  var isNoOp: Bool { inserted == 0 && updated == 0 }
}

/// The confirmed-before-merge count preview presented to the user.
nonisolated struct SessionMergePreview: Sendable, Equatable {

  /// The candidate merge result if confirmed against the sampled local history.
  let result: SessionMergeResult
  /// The inclusive date range in the incoming portable history.
  let dateRange: ClosedRange<Date>?
}

/// A fully normalized import payload retained from preview through confirmation.
nonisolated struct SessionImportPayload: Sendable {

  /// The unique, validated sessions to hand to the atomic repository operation.
  let sessions: [Session]
  /// The duplicate input rows collapsed during normalization.
  let duplicateSkips: Int
}

/// Errors with actionable messages for a rejected portability file or export.
nonisolated enum SessionPortabilityError: LocalizedError, Sendable {

  /// The selected or encoded file exceeded the V1 byte limit.
  case fileTooLarge
  /// The schema version is not supported by this build.
  case unsupportedSchemaVersion(Int)
  /// Required JSON fields could not be decoded.
  case malformedDocument
  /// A record violates a V1 content invariant.
  case invalidRecord(String)
  /// A string field exceeds its V1 UTF-8 byte limit.
  case stringTooLong(String)

  /// A human-readable explanation suitable for a Settings alert.
  var errorDescription: String? {
    switch self {
    case .fileTooLarge: return "Session history files must be 10 MiB or smaller."
    case .unsupportedSchemaVersion(let version):
      return "Session history format version \(version) is not supported."
    case .malformedDocument:
      return "The selected file is not a valid Taskmato session-history file."
    case .invalidRecord(let reason): return "The session-history file is invalid: \(reason)"
    case .stringTooLong(let field):
      return "The session-history file has an oversized \(field) value."
    }
  }
}

/// Encodes, validates, decodes, and previews the first manual portability format.
nonisolated enum SessionPortability {

  /// The only V1 schema version accepted by the explicit decoder switch.
  static let schemaVersion = 1
  /// The maximum encoded document size.
  static let maximumFileBytes = 10 * 1_024 * 1_024
  /// The maximum number of sessions in one V1 document.
  static let maximumSessions = 10_000
  /// The maximum number of segments within one session.
  static let maximumSegmentsPerSession = 128
  /// The maximum number of segments across the whole document.
  static let maximumSegments = 50_000
  /// The small tolerance for floating-point segment sums measured in seconds.
  static let segmentDurationTolerance: TimeInterval = 0.001

  /// Produces a validated V1 document from persisted session history.
  /// - Parameters:
  ///   - sessions: The durable repository snapshot to export.
  ///   - exportedAt: The export timestamp, injectable for deterministic tests.
  /// - Returns: A deterministic, privacy-scoped wire document.
  static func makeDocument(
    sessions: [Session], exportedAt: Date = Date()
  ) throws -> SessionHistoryDocumentV1 {
    let records = sessions.map(record(from:)).sorted(by: recordOrder)
    let document = SessionHistoryDocumentV1(
      schemaVersion: schemaVersion, exportedAt: format(date: exportedAt), sessions: records)
    _ = try decodeAndNormalize(document)
    return document
  }

  /// Encodes a document using a deterministic JSON representation and V1 limits.
  /// - Parameter document: A previously validated V1 document.
  /// - Returns: Portable JSON bytes suitable for `FileDocument` export.
  static func encode(_ document: SessionHistoryDocumentV1) throws -> Data {
    _ = try decodeAndNormalize(document)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let data = try encoder.encode(document)
    guard data.count <= maximumFileBytes else { throw SessionPortabilityError.fileTooLarge }
    return data
  }

  /// Decodes and normalizes a complete V1 document before any database mutation.
  /// - Parameter data: The selected file contents.
  /// - Returns: Unique validated session rows and collapsed-duplicate counts.
  static func decodeAndNormalize(_ data: Data) throws -> SessionImportPayload {
    guard data.count <= maximumFileBytes else { throw SessionPortabilityError.fileTooLarge }
    let document: SessionHistoryDocumentV1
    do {
      document = try JSONDecoder().decode(SessionHistoryDocumentV1.self, from: data)
    } catch {
      throw SessionPortabilityError.malformedDocument
    }
    return try decodeAndNormalize(document)
  }

  /// Validates and normalizes an already-decoded V1 document.
  /// - Parameter document: The decoded V1 envelope.
  /// - Returns: Unique validated session rows and collapsed-duplicate counts.
  static func decodeAndNormalize(
    _ document: SessionHistoryDocumentV1
  ) throws -> SessionImportPayload {
    guard document.schemaVersion == schemaVersion else {
      throw SessionPortabilityError.unsupportedSchemaVersion(document.schemaVersion)
    }
    guard parse(date: document.exportedAt) != nil else {
      throw SessionPortabilityError.invalidRecord("export timestamp is not RFC 3339 UTC")
    }
    guard document.sessions.count <= maximumSessions else {
      throw SessionPortabilityError.invalidRecord("it contains more than 10,000 sessions")
    }

    let validated = try document.sessions.map(validate(record:))
    guard validated.reduce(0, { $0 + $1.record.segments.count }) <= maximumSegments else {
      throw SessionPortabilityError.invalidRecord("it contains more than 50,000 focus segments")
    }
    guard validated.reduce(0, { $0 + stringBytes(in: $1.record) }) <= 4 * 1_024 * 1_024 else {
      throw SessionPortabilityError.invalidRecord("its combined text exceeds 4 MiB")
    }
    var grouped: [UUID: [ValidatedRecord]] = [:]
    for record in validated { grouped[record.record.id, default: []].append(record) }

    var normalized: [ValidatedRecord] = []
    var duplicateSkips = 0
    for candidates in grouped.values {
      guard let greatestEnd = candidates.map(\.endedAt).max() else { continue }
      let winners = candidates.filter { $0.endedAt == greatestEnd }
      guard let winner = winners.first else { continue }
      guard winners.dropFirst().allSatisfy({ $0.record == winner.record }) else {
        throw SessionPortabilityError.invalidRecord(
          "duplicate session \(winner.record.id) has divergent equal end times")
      }
      normalized.append(winner)
      duplicateSkips += candidates.count - 1
    }

    let sessions = normalized.map(\.session).sorted(by: sessionOrder)
    return SessionImportPayload(sessions: sessions, duplicateSkips: duplicateSkips)
  }

  /// Computes deterministic merge counts from an imported payload and a durable local snapshot.
  /// - Parameters:
  ///   - payload: The normalized portable payload.
  ///   - localSessions: The durable history sampled for this preview.
  /// - Returns: The date range and merge result that require user confirmation.
  static func preview(
    payload: SessionImportPayload, localSessions: [Session]
  ) -> SessionMergePreview {
    var result = SessionMergeResult(skipped: payload.duplicateSkips)
    let localByID = Dictionary(uniqueKeysWithValues: localSessions.map { ($0.id, $0) })
    for session in payload.sessions {
      guard let local = localByID[session.id] else {
        result.inserted += 1
        continue
      }
      if session.endedAt > local.endedAt {
        result.updated += 1
      } else if session.endedAt < local.endedAt || session == local {
        result.skipped += 1
      } else {
        result.conflicts += 1
      }
    }
    let dates = payload.sessions.flatMap { [$0.startedAt, $0.endedAt] }
    return SessionMergePreview(
      result: result, dateRange: dates.min().flatMap { start in dates.max().map { start...$0 } })
  }

  private static func validate(record: SessionRecordV1) throws -> ValidatedRecord {
    guard let phase = SessionPhase(rawValue: record.phase),
      let startedAt = parse(date: record.startedAt), let endedAt = parse(date: record.endedAt)
    else { throw SessionPortabilityError.invalidRecord("a phase or timestamp is invalid") }
    guard endedAt >= startedAt else {
      throw SessionPortabilityError.invalidRecord("a session ends before it starts")
    }
    guard record.segments.count <= maximumSegmentsPerSession else {
      throw SessionPortabilityError.invalidRecord("a session has more than 128 focus segments")
    }
    guard phase == .focus || record.segments.isEmpty else {
      throw SessionPortabilityError.invalidRecord("a break session has focus segments")
    }
    var ids = Set<UUID>()
    let segmentSeconds = try validate(segments: record.segments, ids: &ids)
    guard segmentSeconds <= endedAt.timeIntervalSince(startedAt) + segmentDurationTolerance else {
      throw SessionPortabilityError.invalidRecord("focus segments exceed the session duration")
    }
    return ValidatedRecord(
      record: record, endedAt: endedAt,
      session: Session(
        id: record.id, phase: phase, startedAt: startedAt, endedAt: endedAt,
        wasCompleted: record.wasCompleted,
        segments: record.segments.map(segment(from:))))
  }

  private static func validate(_ value: String, maximum: Int, field: String) throws {
    guard value.utf8.count <= maximum else { throw SessionPortabilityError.stringTooLong(field) }
  }

  private static func validate(
    segments: [FocusSegmentV1], ids: inout Set<UUID>
  ) throws -> TimeInterval {
    var total: TimeInterval = 0
    for segment in segments {
      guard ids.insert(segment.id).inserted else {
        throw SessionPortabilityError.invalidRecord(
          "a session has duplicate focus-segment identifiers")
      }
      guard segment.seconds.isFinite, segment.seconds > 0 else {
        throw SessionPortabilityError.invalidRecord("a focus segment has a non-positive duration")
      }
      total += segment.seconds
      if let ref = segment.taskRef {
        try validate(ref.providerID, maximum: 256, field: "provider identifier")
        try validate(ref.nativeID, maximum: 16 * 1_024, field: "provider-native task identifier")
      }
      if let title = segment.taskTitle {
        try validate(title, maximum: 16 * 1_024, field: "task-title snapshot")
      }
      if let label = segment.providerLabel {
        try validate(label, maximum: 1_024, field: "provider-label snapshot")
      }
    }
    return total
  }

  private static func stringBytes(in record: SessionRecordV1) -> Int {
    record.segments.reduce(0) { total, segment in
      total + (segment.taskRef?.providerID.utf8.count ?? 0)
        + (segment.taskRef?.nativeID.utf8.count ?? 0)
        + (segment.taskTitle?.utf8.count ?? 0)
        + (segment.providerLabel?.utf8.count ?? 0)
    }
  }

  private static func record(from session: Session) -> SessionRecordV1 {
    SessionRecordV1(
      id: session.id, phase: session.phase.rawValue, startedAt: format(date: session.startedAt),
      endedAt: format(date: session.endedAt), wasCompleted: session.wasCompleted,
      segments: session.segments.map { segment in
        FocusSegmentV1(
          id: segment.id,
          taskRef: segment.taskRef.map {
            TaskRefV1(providerID: $0.providerID.rawValue, nativeID: $0.nativeID)
          },
          taskTitle: segment.taskTitle, seconds: segment.seconds,
          providerLabel: segment.providerLabel, providerTint: segment.providerTint)
      })
  }

  private static func segment(from segment: FocusSegmentV1) -> FocusSegment {
    FocusSegment(
      id: segment.id,
      taskRef: segment.taskRef.map {
        TaskRef(providerID: ProviderID($0.providerID), nativeID: $0.nativeID)
      },
      taskTitle: segment.taskTitle, seconds: segment.seconds,
      providerLabel: segment.providerLabel, providerTint: segment.providerTint)
  }

  private static func format(date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: date)
  }

  private static func parse(date: String) -> Date? {
    let formatter = ISO8601DateFormatter()
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.date(from: date)
  }

  private static func recordOrder(_ lhs: SessionRecordV1, _ rhs: SessionRecordV1) -> Bool {
    guard lhs.startedAt != rhs.startedAt else {
      return lhs.endedAt == rhs.endedAt
        ? lhs.id.uuidString < rhs.id.uuidString : lhs.endedAt < rhs.endedAt
    }
    return lhs.startedAt < rhs.startedAt
  }

  private static func sessionOrder(_ lhs: Session, _ rhs: Session) -> Bool {
    guard lhs.startedAt != rhs.startedAt else {
      return lhs.endedAt == rhs.endedAt
        ? lhs.id.uuidString < rhs.id.uuidString : lhs.endedAt < rhs.endedAt
    }
    return lhs.startedAt < rhs.startedAt
  }

  private struct ValidatedRecord {
    let record: SessionRecordV1
    let endedAt: Date
    let session: Session
  }
}

/// The system-file-exporter document wrapper around validated session-history JSON.
nonisolated struct SessionHistoryFile: FileDocument, Sendable {

  /// The exact portable JSON bytes supplied to SwiftUI's system exporter.
  let data: Data

  /// The one supported document type.
  static var readableContentTypes: [UTType] { [.json] }

  /// Reads the selected file bytes for callers that use `FileDocument` directly.
  /// - Parameter configuration: The system-provided file-read configuration.
  init(configuration: ReadConfiguration) throws {
    guard let data = configuration.file.regularFileContents else {
      throw SessionPortabilityError.malformedDocument
    }
    _ = try SessionPortability.decodeAndNormalize(data)
    self.data = data
  }

  /// Builds an exportable document from already validated JSON bytes.
  /// - Parameter data: The portable JSON to save.
  init(data: Data) { self.data = data }

  /// Supplies the portable bytes to the save panel's selected destination.
  /// - Parameter configuration: The system-provided write configuration.
  /// - Returns: The JSON-backed file wrapper.
  func fileWrapper(configuration _: WriteConfiguration) throws -> FileWrapper {
    FileWrapper(regularFileWithContents: data)
  }
}
