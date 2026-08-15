//
//  SessionSummary.swift
//  Taskmato
//

import Foundation

/// Aggregated statistics computed from a set of session records over a date interval.
///
/// Constructed by ``SessionStore/summary(for:)`` or its convenience methods. All properties
/// are eagerly computed at init time from the provided sessions; the value is immutable.
struct SessionSummary {

  /// Number of naturally completed focus sessions within the interval.
  let focusCount: Int

  /// Total elapsed time across every focus segment, regardless of the owning phase's
  /// completion, in seconds.
  let focusSeconds: TimeInterval

  /// Number of naturally completed break sessions (short or long) within the interval.
  let breakCount: Int

  /// Number of completed full Pomodoro cycles within the interval.
  ///
  /// One cycle = one completed long break. A long break is only taken after the user
  /// finishes N consecutive focus sessions, so each completed long break represents
  /// one full cycle.
  let cycleCount: Int

  /// Focus time grouped by task, sorted by total duration descending.
  let taskBreakdown: [TaskSlice]

  /// A single task's share of focus time within the summary interval.
  struct TaskSlice: Identifiable {

    /// Stable grouping key derived from the task's provider ID and native ID.
    let id: String

    /// Human-readable task title shown in the pie chart legend.
    let label: String

    /// Total focus seconds attributed to this task.
    let seconds: TimeInterval
  }

  /// Computes a summary from sessions whose `startedAt` falls within `interval`.
  ///
  /// Per design doc 0010 (D5), counts and time measure different populations: session, cycle,
  /// and break **counts** stay gated on `wasCompleted` — the pomodoro is indivisible — while
  /// focus **time** and the task breakdown sum every focus segment regardless of completion, so
  /// invested time from a stopped or skipped phase is still credited.
  /// - Parameters:
  ///   - sessions: The full session log, as returned by ``SessionStore``.
  ///   - interval: The date range to scope results to.
  init(sessions: [Session], over interval: DateInterval) {
    let scoped = sessions.filter { interval.contains($0.startedAt) }
    let completedFocus = scoped.filter { $0.phase == .focus && $0.wasCompleted }
    let allFocus = scoped.filter { $0.phase == .focus }

    focusCount = completedFocus.count

    breakCount =
      scoped.filter {
        ($0.phase == .shortBreak || $0.phase == .longBreak) && $0.wasCompleted
      }.count

    cycleCount = scoped.filter { $0.phase == .longBreak && $0.wasCompleted }.count

    // Group every focus segment by task, regardless of the owning phase's completion,
    // preserving first-seen insertion order so the breakdown order is deterministic before
    // the final sort.
    var ordered: [String] = []
    var accumulated: [String: (label: String, seconds: TimeInterval)] = [:]
    var totalFocusSeconds: TimeInterval = 0

    for session in allFocus {
      for segment in session.segments {
        totalFocusSeconds += segment.seconds
        let key: String
        let label: String
        if let ref = segment.taskRef {
          key = "\(ref.providerID.rawValue):\(ref.nativeID)"
          label = segment.taskTitle ?? "Unknown Task"
        } else {
          key = "__untracked__"
          label = "Untracked"
        }
        if accumulated[key] == nil {
          ordered.append(key)
          accumulated[key] = (label: label, seconds: 0)
        }
        accumulated[key]!.seconds += segment.seconds
      }
    }

    focusSeconds = totalFocusSeconds
    taskBreakdown =
      ordered
      .compactMap { key -> TaskSlice? in
        guard let entry = accumulated[key] else { return nil }
        return TaskSlice(id: key, label: entry.label, seconds: entry.seconds)
      }
      .sorted { $0.seconds > $1.seconds }
  }
}
