//
//  SessionIndicators.swift
//  Taskmato
//

/// Which session indicators the window shows for a given engine state and destination.
///
/// Encodes the ambient-badge / working-strip contract: the sidebar Timer badge is an
/// always-on ambient countdown whenever the session is non-idle, while the pinned strip is
/// the working control surface shown only away from the Timer destination. The two are not
/// mutually exclusive — off the Timer destination both appear together.
struct SessionIndicators: Equatable {

  /// Whether the pinned timer strip is shown below the detail column.
  let showStrip: Bool
  /// Whether the sidebar Timer row shows its countdown badge.
  let showBadge: Bool

  /// Resolves the indicators from the non-idle predicate and whether Timer is the destination.
  /// - Parameters:
  ///   - isNonIdle: Whether a session is running or paused (`false` only when idle).
  ///   - onTimer: Whether the current destination is the Timer surface.
  init(isNonIdle: Bool, onTimer: Bool) {
    showBadge = isNonIdle
    showStrip = isNonIdle && !onTimer
  }
}
