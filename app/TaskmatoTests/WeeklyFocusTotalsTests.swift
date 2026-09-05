//
//  WeeklyFocusTotalsTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

@MainActor
struct WeeklyFocusTotalsTests {

  @Test func refreshesOneCalendarClockSnapshotForTodayAndWeeklyProjections() async {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    calendar.firstWeekday = 2
    let monday = calendar.date(from: DateComponents(year: 2026, month: 3, day: 2, hour: 9))!
    var now = monday
    let store = SessionStore(
      repository: FakeSessionRepository(sessions: [
        session(start: monday, seconds: 60, done: true, task: nil)
      ]))
    await store.reload()
    let viewModel = StatsViewModel(
      store: store, calendarProvider: { calendar }, nowProvider: { now })

    #expect(viewModel.todayFocusCount == 1)
    now = calendar.date(byAdding: .day, value: 1, to: monday)!
    #expect(viewModel.todayFocusCount == 1)
    viewModel.refreshTemporalContext()
    #expect(viewModel.todayFocusCount == 0)
    #expect(viewModel.weeklyFocusTotals.first?.seconds == 60)
  }

  @Test func groupsSessionStartWeeksAndKeepsIncompleteUntrackedTime() async {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    calendar.firstWeekday = 2
    let monday = calendar.date(from: DateComponents(year: 2026, month: 12, day: 28, hour: 23))!
    let nextMonday = calendar.date(byAdding: .day, value: 7, to: monday)!
    let local = TaskRef(providerID: ProviderID("local"), nativeID: "local-task")
    let sessions = [
      session(start: monday, seconds: 30, done: false, task: local),
      session(start: monday, seconds: 45, done: true, task: nil),
      session(start: nextMonday, seconds: 60, done: true, task: local),
      Session(
        id: UUID(), phase: .shortBreak, startedAt: monday,
        endedAt: monday.addingTimeInterval(90), wasCompleted: true),
    ]
    let store = SessionStore(repository: FakeSessionRepository(sessions: sessions))
    await store.reload()
    let viewModel = StatsViewModel(
      store: store, calendarProvider: { calendar }, nowProvider: { monday })

    let totals = viewModel.weeklyFocusTotals
    let firstWeek = calendar.dateInterval(of: .weekOfYear, for: monday)?.start
    let secondWeek = calendar.dateInterval(of: .weekOfYear, for: nextMonday)?.start
    #expect(totals.count == 3)
    #expect(totals.first { $0.providerID == "local" && $0.week == firstWeek }?.seconds == 30)
    #expect(totals.first { $0.providerID == "__untracked__" }?.seconds == 45)
    #expect(totals.first { $0.week == secondWeek }?.seconds == 60)
  }

  @Test func keepsProviderSnapshotTintInWeeklyTotals() async {
    let now = Date(timeIntervalSinceReferenceDate: 900_000)
    let ref = TaskRef(providerID: ProviderID("missing"), nativeID: "task")
    let record = Session(
      id: UUID(), phase: .focus, startedAt: now, endedAt: now.addingTimeInterval(30),
      wasCompleted: false,
      segments: [
        FocusSegment(
          id: UUID(), taskRef: ref, taskTitle: "Task", seconds: 30,
          providerLabel: "Archived", providerTint: .purple)
      ])
    let store = SessionStore(repository: FakeSessionRepository(sessions: [record]))
    await store.reload()
    let viewModel = StatsViewModel(store: store, nowProvider: { now })

    #expect(viewModel.weeklyFocusTotals.first?.tint == .purple)
    #expect(viewModel.weeklyFocusProviders.first?.label == "Archived")
  }

  private func session(start: Date, seconds: TimeInterval, done: Bool, task: TaskRef?) -> Session {
    Session(
      id: UUID(), phase: .focus, startedAt: start, endedAt: start.addingTimeInterval(seconds),
      wasCompleted: done,
      segments: [FocusSegment(id: UUID(), taskRef: task, taskTitle: nil, seconds: seconds)])
  }
}
