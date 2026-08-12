//
//  Session.swift
//  Taskmato
//

import Foundation

/// A contiguous run of focus time within one phase, attributed to a single task (or none).
///
/// A phase's timeline is partitioned into segments at each task change, so multiple segments
/// can share one ``Session`` when the active task changed mid-phase (complete, swap, or clear).
nonisolated struct FocusSegment: Codable, Sendable, Identifiable, Equatable {

  /// Stable identifier for this slice.
  let id: UUID

  /// The task this slice of focus time is attributed to; `nil` for untracked focus.
  let taskRef: TaskRef?

  /// Task title captured at slice close, so stats survive renames/deletes.
  let taskTitle: String?

  /// Focus seconds attributed to this slice.
  let seconds: TimeInterval

  /// Provider display name captured at slice close, so ported or synced stats render the real
  /// name with the provider absent (ADR-0010, D4).
  ///
  /// `nil` for untracked focus, for a provider missing from the registry at capture time, and
  /// for records written before D4.
  let providerLabel: String?

  /// Provider semantic tint captured at slice close; `nil` under the same conditions as
  /// ``providerLabel``.
  let providerTint: ProviderTint?

  /// Creates a focus slice.
  /// - Parameters:
  ///   - providerLabel: Provider display-name snapshot; omit when the provider does not resolve.
  ///   - providerTint: Provider tint snapshot; omit when the provider does not resolve.
  init(
    id: UUID, taskRef: TaskRef?, taskTitle: String?, seconds: TimeInterval,
    providerLabel: String? = nil, providerTint: ProviderTint? = nil
  ) {
    self.id = id
    self.taskRef = taskRef
    self.taskTitle = taskTitle
    self.seconds = seconds
    self.providerLabel = providerLabel
    self.providerTint = providerTint
  }
}

/// An immutable record of a single Pomodoro phase.
nonisolated struct Session: Codable, Identifiable, Sendable {

  /// Stable unique identifier for this session record.
  let id: UUID

  /// The phase that was completed.
  let phase: SessionPhase

  /// Wall-clock time when this phase began.
  let startedAt: Date

  /// Wall-clock time when this phase ended naturally (not stopped manually).
  let endedAt: Date

  /// `true` if the phase ran to completion naturally; `false` if the user stopped it early.
  let wasCompleted: Bool

  /// The per-task attribution of this phase's focus time, in the order the tasks held focus.
  ///
  /// Empty for break phases and for focus phases run with no task selected. The sum of
  /// `segments.map(\.seconds)` equals the phase's consumed focus time — `duration` for a
  /// completed phase, less for one stopped or skipped early.
  var segments: [FocusSegment]

  /// Actual elapsed duration of this phase in seconds.
  var duration: TimeInterval { endedAt.timeIntervalSince(startedAt) }

  /// Creates a session record from explicit field values.
  /// - Parameter segments: The per-task focus attribution for this phase; defaults to none.
  init(
    id: UUID, phase: SessionPhase, startedAt: Date, endedAt: Date, wasCompleted: Bool,
    segments: [FocusSegment] = []
  ) {
    self.id = id
    self.phase = phase
    self.startedAt = startedAt
    self.endedAt = endedAt
    self.wasCompleted = wasCompleted
    self.segments = segments
  }
}
