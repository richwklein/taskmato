//
//  SessionEntity.swift
//  Taskmato
//

import Foundation
import SwiftData

/// The SwiftData persistence record mirroring a ``Session``'s stored fields.
///
/// `segments` is stored as a native SwiftData transformable (D6 of design doc 0010) — SwiftData
/// persists arrays of `Codable` value types directly, so no hand-rolled `Data` blob is needed.
/// The flattened `taskProviderID`/`taskNativeID`/`taskTitle` columns are kept for **read-only**
/// backward compatibility with rows written before segments existed; new writes populate
/// `segments` and mirror the first slice into the flat columns. `phase` is stored directly as
/// its `String` raw value.
@Model
final class SessionEntity {

  /// Stable unique identifier and the record's identity.
  @Attribute(.unique) var id: UUID

  /// The phase that was completed.
  var phase: SessionPhase

  /// Wall-clock time when this phase began; the only attribute ever predicated on.
  var startedAt: Date

  /// Wall-clock time when this phase ended naturally.
  var endedAt: Date

  /// `true` if the phase ran to natural completion.
  var wasCompleted: Bool

  /// Per-task focus attribution. Defaults to `[]` so adding this property is a lightweight
  /// migration for rows persisted before design doc 0010.
  var segments: [FocusSegment] = []

  /// Flattened ``TaskRef/providerID`` of the first slice; `nil` when no task was selected.
  /// Legacy pre-segments rows only ever populated this column — read-only going forward.
  var taskProviderID: String?

  /// Flattened ``TaskRef/nativeID`` of the first slice; `nil` when no task was selected.
  var taskNativeID: String?

  /// Task display title of the first slice, captured at session end.
  var taskTitle: String?

  /// Creates a persistence record from explicit field values.
  init(
    id: UUID, phase: SessionPhase, startedAt: Date, endedAt: Date, wasCompleted: Bool,
    segments: [FocusSegment], taskProviderID: String?, taskNativeID: String?, taskTitle: String?
  ) {
    self.id = id
    self.phase = phase
    self.startedAt = startedAt
    self.endedAt = endedAt
    self.wasCompleted = wasCompleted
    self.segments = segments
    self.taskProviderID = taskProviderID
    self.taskNativeID = taskNativeID
    self.taskTitle = taskTitle
  }
}

extension SessionEntity {

  /// Creates a persistence record from a domain ``Session``.
  ///
  /// The legacy flat columns mirror the first segment, so a valid single-task snapshot survives
  /// even if a future build reads this row without `segments` support.
  convenience init(session: Session) {
    let flat = Self.flatFields(from: session)
    self.init(
      id: session.id, phase: session.phase, startedAt: session.startedAt,
      endedAt: session.endedAt, wasCompleted: session.wasCompleted,
      segments: session.segments,
      taskProviderID: flat.providerID,
      taskNativeID: flat.nativeID,
      taskTitle: flat.title)
  }

  /// Updates this record's fields in place from a domain ``Session``, keeping its identity —
  /// the mutate branch of ``SwiftDataSessionRepository/upsert(_:)``.
  /// - Parameter session: The session to copy fields from.
  func update(from session: Session) {
    phase = session.phase
    startedAt = session.startedAt
    endedAt = session.endedAt
    wasCompleted = session.wasCompleted
    segments = session.segments
    let flat = Self.flatFields(from: session)
    taskProviderID = flat.providerID
    taskNativeID = flat.nativeID
    taskTitle = flat.title
  }

  /// The legacy flat-column values mirrored from a session's first segment.
  private struct FlatFields {
    let providerID: String?
    let nativeID: String?
    let title: String?
  }

  /// Flattens a session's first segment into the legacy read-only columns.
  private static func flatFields(from session: Session) -> FlatFields {
    let first = session.segments.first
    return FlatFields(
      providerID: first?.taskRef?.providerID.rawValue, nativeID: first?.taskRef?.nativeID,
      title: first?.taskTitle)
  }
}

extension Session {

  /// Reconstructs a domain ``Session`` from its persistence record.
  nonisolated init(entity: SessionEntity) {
    self.init(
      id: entity.id, phase: entity.phase, startedAt: entity.startedAt,
      endedAt: entity.endedAt, wasCompleted: entity.wasCompleted,
      segments: Self.resolvedSegments(from: entity))
  }

  /// Resolves a persistence record's segments, preferring `entity.segments` when present.
  ///
  /// Otherwise synthesizes a single slice from the legacy flat fields spanning the whole
  /// duration (D6), scoped to focus phases only so a legacy break row's incidental flat fields
  /// never violate the "breaks carry no segments" invariant. A legacy row with no task recorded
  /// resolves to `[]`.
  private nonisolated static func resolvedSegments(from entity: SessionEntity) -> [FocusSegment] {
    guard entity.segments.isEmpty else { return entity.segments }
    guard entity.phase == .focus else { return [] }
    guard let providerID = entity.taskProviderID, let nativeID = entity.taskNativeID else {
      return []
    }
    let ref = TaskRef(providerID: ProviderID(providerID), nativeID: nativeID)
    return [
      FocusSegment(
        id: UUID(), taskRef: ref, taskTitle: entity.taskTitle,
        seconds: entity.endedAt.timeIntervalSince(entity.startedAt))
    ]
  }
}
