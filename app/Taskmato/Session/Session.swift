//
//  Session.swift
//  Taskmato
//

import Foundation

/// An immutable record of a single completed Pomodoro phase.
struct Session: Codable, Identifiable {

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

    /// The EventKit reminder identifier associated with this session, if any.
    /// Populated once Reminders integration is added.
    var reminderID: String?

    /// Actual elapsed duration of this phase in seconds.
    var duration: TimeInterval { endedAt.timeIntervalSince(startedAt) }
}
