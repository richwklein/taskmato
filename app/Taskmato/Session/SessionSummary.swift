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

  /// Total elapsed time across completed focus sessions, in seconds.
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

  /// Total focus time expressed in whole minutes.
  var focusMinutes: Int { Int(focusSeconds / 60) }

  /// A single task's share of focus time within the summary interval.
  struct TaskSlice: Identifiable {

    /// Stable grouping key derived from the task's provider ID and native ID.
    let id: String

    /// Human-readable task title shown in the pie chart legend.
    let label: String

    /// Total focus seconds attributed to this task.
    let seconds: TimeInterval

    /// Focus time expressed in whole minutes.
    var minutes: Int { Int(seconds / 60) }
  }

  /// Computes a summary from sessions whose `startedAt` falls within `interval`.
  ///
  /// - Parameters:
  ///   - sessions: The full session log, as returned by ``SessionStore``.
  ///   - interval: The date range to scope results to.
  init(sessions: [Session], over interval: DateInterval) {
    let scoped = sessions.filter { interval.contains($0.startedAt) }
    let completedFocus = scoped.filter { $0.phase == .focus && $0.wasCompleted }

    focusCount = completedFocus.count
    focusSeconds = completedFocus.reduce(0) { $0 + $1.duration }

    breakCount =
      scoped.filter {
        ($0.phase == .shortBreak || $0.phase == .longBreak) && $0.wasCompleted
      }.count

    cycleCount = scoped.filter { $0.phase == .longBreak && $0.wasCompleted }.count

    // Group completed focus sessions by task, preserving first-seen insertion order
    // so the breakdown order is deterministic before the final sort.
    var ordered: [String] = []
    var accumulated: [String: (label: String, seconds: TimeInterval)] = [:]

    for session in completedFocus {
      let key: String
      let label: String
      if let ref = session.taskRef {
        key = "\(ref.providerID):\(ref.nativeID)"
        label = session.taskTitle ?? "Unknown Task"
      } else {
        key = "__untracked__"
        label = "Untracked"
      }
      if accumulated[key] == nil {
        ordered.append(key)
        accumulated[key] = (label: label, seconds: 0)
      }
      accumulated[key]!.seconds += session.duration
    }

    taskBreakdown =
      ordered
      .compactMap { key -> TaskSlice? in
        guard let entry = accumulated[key] else { return nil }
        return TaskSlice(id: key, label: entry.label, seconds: entry.seconds)
      }
      .sorted { $0.seconds > $1.seconds }
  }
}
