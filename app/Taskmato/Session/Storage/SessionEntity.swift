//
//  SessionEntity.swift
//  Taskmato
//

import Foundation
import SwiftData

/// The SwiftData persistence record mirroring a ``Session``'s stored fields.
///
/// `taskRef` is flattened into `taskProviderID`/`taskNativeID` (never queried, so kept as
/// schema-stable optional strings). `phase` is stored directly as its `String` raw value.
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

  /// Flattened ``TaskRef/providerID``; `nil` when no task was selected.
  var taskProviderID: String?

  /// Flattened ``TaskRef/nativeID``; `nil` when no task was selected.
  var taskNativeID: String?

  /// Task display title captured at session end.
  var taskTitle: String?

  /// Creates a persistence record from explicit field values.
  init(
    id: UUID, phase: SessionPhase, startedAt: Date, endedAt: Date, wasCompleted: Bool,
    taskProviderID: String?, taskNativeID: String?, taskTitle: String?
  ) {
    self.id = id
    self.phase = phase
    self.startedAt = startedAt
    self.endedAt = endedAt
    self.wasCompleted = wasCompleted
    self.taskProviderID = taskProviderID
    self.taskNativeID = taskNativeID
    self.taskTitle = taskTitle
  }
}

extension SessionEntity {

  /// Creates a persistence record from a domain ``Session``.
  convenience init(session: Session) {
    self.init(
      id: session.id, phase: session.phase, startedAt: session.startedAt,
      endedAt: session.endedAt, wasCompleted: session.wasCompleted,
      taskProviderID: session.taskRef?.providerID,
      taskNativeID: session.taskRef?.nativeID,
      taskTitle: session.taskTitle)
  }
}

extension Session {

  /// Reconstructs a domain ``Session`` from its persistence record.
  init(entity: SessionEntity) {
    let taskRef: TaskRef?
    if let providerID = entity.taskProviderID, let nativeID = entity.taskNativeID {
      taskRef = TaskRef(providerID: providerID, nativeID: nativeID)
    } else {
      taskRef = nil
    }
    self.init(
      id: entity.id, phase: entity.phase, startedAt: entity.startedAt,
      endedAt: entity.endedAt, wasCompleted: entity.wasCompleted,
      taskRef: taskRef, taskTitle: entity.taskTitle)
  }
}
