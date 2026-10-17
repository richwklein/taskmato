//
//  PhaseEndOutcome.swift
//  Taskmato
//

/// How the phase after a completed one was resolved, as reported by the phase-end banner.
enum PhaseEndOutcome: Equatable, Sendable {
  /// The next phase is running.
  case started
  /// The next phase is queued for a manual Start.
  case queued
  /// Focus is queued but can't start until a task is tracked or staged (D11 of design doc 0010).
  case awaitingTask
}
