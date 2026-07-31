//
//  PhaseEvent.swift
//  Taskmato
//

import Foundation

/// An event emitted by ``SessionEngine`` when a phase ends.
enum PhaseEvent: Sendable {
  /// A phase ended, naturally or via manual stop.
  /// - Parameters:
  ///   - phase: The phase that ended.
  ///   - startedAt: Virtual start time, reflecting actual accumulated focus time.
  ///   - endedAt: The wall-clock time the phase ended.
  ///   - wasCompleted: `true` if time ran out naturally; `false` if the user stopped manually.
  case ended(phase: SessionPhase, startedAt: Date, endedAt: Date, wasCompleted: Bool)
}
