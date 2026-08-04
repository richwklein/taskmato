//
//  PhaseEvent.swift
//  Taskmato
//

import Foundation

/// An event emitted by ``SessionEngine`` as a phase begins or ends.
enum PhaseEvent: Sendable {
  /// A fresh phase began, from `start()` or `skip()` — never from `resume()`. The one seam
  /// every start path funnels through, so ``FocusAttribution`` can seed once per phase
  /// (D4 of design doc 0010).
  /// - Parameter phase: The phase that began.
  case began(phase: SessionPhase)

  /// A phase ended, naturally, via manual stop, or (for focus) via skip.
  /// - Parameters:
  ///   - phase: The phase that ended.
  ///   - startedAt: Virtual start time, reflecting actual accumulated focus time.
  ///   - endedAt: The wall-clock time the phase ended.
  ///   - wasCompleted: `true` if time ran out naturally; `false` if the user stopped or skipped.
  case ended(phase: SessionPhase, startedAt: Date, endedAt: Date, wasCompleted: Bool)
}
