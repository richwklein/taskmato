//
//  SessionSummaryTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

struct SessionSummaryTests {

  // MARK: - Helpers

  private static let epoch = Date(timeIntervalSinceReferenceDate: 0)
  private static let day: TimeInterval = 86_400
  private static let focusDuration: TimeInterval = 1_500  // 25 min

  private static let todayInterval: DateInterval = {
    let cal = Calendar.current
    let start = cal.startOfDay(for: epoch)
    let end = cal.date(byAdding: .day, value: 1, to: start)!
    return DateInterval(start: start, end: end)
  }()

  private func makeSession(
    phase: SessionPhase = .focus,
    startedAt: Date = epoch,
    duration: TimeInterval = focusDuration,
    wasCompleted: Bool = true,
    taskRef: TaskRef? = nil,
    taskTitle: String? = nil
  ) -> Session {
    Session(
      id: UUID(),
      phase: phase,
      startedAt: startedAt,
      endedAt: startedAt.addingTimeInterval(duration),
      wasCompleted: wasCompleted,
      taskRef: taskRef,
      taskTitle: taskTitle
    )
  }

  // MARK: - Empty input

  @Test func emptySessionsProducesAllZeros() {
    let summary = SessionSummary(sessions: [], over: Self.todayInterval)
    #expect(summary.focusCount == 0)
    #expect(summary.focusSeconds == 0)
    #expect(summary.breakCount == 0)
    #expect(summary.cycleCount == 0)
    #expect(summary.taskBreakdown.isEmpty)
  }

  // MARK: - Interval scoping

  @Test func sessionOutsideIntervalIsExcluded() {
    let outside = makeSession(startedAt: Self.epoch.addingTimeInterval(-Self.day))
    let summary = SessionSummary(sessions: [outside], over: Self.todayInterval)
    #expect(summary.focusCount == 0)
  }

  @Test func sessionInsideIntervalIsCounted() {
    let inside = makeSession(startedAt: Self.epoch)
    let summary = SessionSummary(sessions: [inside], over: Self.todayInterval)
    #expect(summary.focusCount == 1)
  }

  // MARK: - Focus counting

  @Test func incompleteFocusSessionExcludedFromCount() {
    let partial = makeSession(wasCompleted: false)
    let summary = SessionSummary(sessions: [partial], over: Self.todayInterval)
    #expect(summary.focusCount == 0)
    #expect(summary.focusSeconds == 0)
  }

  @Test func focusSecondsAccumulatesCompletedDurations() {
    let first = makeSession(duration: 1_500)
    let second = makeSession(duration: 900)
    let summary = SessionSummary(sessions: [first, second], over: Self.todayInterval)
    #expect(summary.focusSeconds == 2_400)
    #expect(summary.focusMinutes == 40)
  }

  // MARK: - Break counting

  @Test func shortBreakCountedAsBreak() {
    let session = makeSession(phase: .shortBreak)
    let summary = SessionSummary(sessions: [session], over: Self.todayInterval)
    #expect(summary.breakCount == 1)
  }

  @Test func longBreakCountedAsBreakAndCycle() {
    let session = makeSession(phase: .longBreak)
    let summary = SessionSummary(sessions: [session], over: Self.todayInterval)
    #expect(summary.breakCount == 1)
    #expect(summary.cycleCount == 1)
  }

  @Test func shortBreakDoesNotIncrementCycleCount() {
    let session = makeSession(phase: .shortBreak)
    let summary = SessionSummary(sessions: [session], over: Self.todayInterval)
    #expect(summary.cycleCount == 0)
  }

  @Test func incompleteLongBreakExcludedFromCycleCount() {
    let session = makeSession(phase: .longBreak, wasCompleted: false)
    let summary = SessionSummary(sessions: [session], over: Self.todayInterval)
    #expect(summary.cycleCount == 0)
  }

  // MARK: - Task breakdown

  @Test func untrackedSessionAppearsAsUntracked() {
    let session = makeSession(taskRef: nil, taskTitle: nil)
    let summary = SessionSummary(sessions: [session], over: Self.todayInterval)
    #expect(summary.taskBreakdown.count == 1)
    #expect(summary.taskBreakdown.first?.label == "Untracked")
  }

  @Test func sessionWithTitleUsesStoredTitle() {
    let ref = TaskRef(providerID: "local", nativeID: "abc")
    let session = makeSession(taskRef: ref, taskTitle: "Design Review")
    let summary = SessionSummary(sessions: [session], over: Self.todayInterval)
    #expect(summary.taskBreakdown.first?.label == "Design Review")
  }

  @Test func sessionWithRefButNoTitleFallsBackToUnknown() {
    let ref = TaskRef(providerID: "local", nativeID: "abc")
    let session = makeSession(taskRef: ref, taskTitle: nil)
    let summary = SessionSummary(sessions: [session], over: Self.todayInterval)
    #expect(summary.taskBreakdown.first?.label == "Unknown Task")
  }

  @Test func sessionsForSameTaskAreGrouped() {
    let ref = TaskRef(providerID: "local", nativeID: "abc")
    let first = makeSession(duration: 1_500, taskRef: ref, taskTitle: "Design Review")
    let second = makeSession(duration: 900, taskRef: ref, taskTitle: "Design Review")
    let summary = SessionSummary(sessions: [first, second], over: Self.todayInterval)
    #expect(summary.taskBreakdown.count == 1)
    #expect(summary.taskBreakdown.first?.seconds == 2_400)
  }

  @Test func breakdownSortedByDurationDescending() {
    let refA = TaskRef(providerID: "local", nativeID: "a")
    let refB = TaskRef(providerID: "local", nativeID: "b")
    let short = makeSession(duration: 600, taskRef: refA, taskTitle: "Short")
    let long = makeSession(duration: 1_500, taskRef: refB, taskTitle: "Long")
    let summary = SessionSummary(sessions: [short, long], over: Self.todayInterval)
    #expect(summary.taskBreakdown.first?.label == "Long")
    #expect(summary.taskBreakdown.last?.label == "Short")
  }

  @Test func breakSessionsExcludedFromTaskBreakdown() {
    let session = makeSession(phase: .shortBreak)
    let summary = SessionSummary(sessions: [session], over: Self.todayInterval)
    #expect(summary.taskBreakdown.isEmpty)
  }
}
