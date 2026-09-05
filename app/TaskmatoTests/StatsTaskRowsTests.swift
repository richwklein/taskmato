//
//  StatsTaskRowsTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

@MainActor
struct StatsTaskRowsTests {

  @Test func taskRowsHonorTheSelectedScope() async {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let now = calendar.date(from: DateComponents(year: 2026, month: 4, day: 10, hour: 15))!
    let today = calendar.date(from: DateComponents(year: 2026, month: 4, day: 10, hour: 9))!
    let longAgo = calendar.date(from: DateComponents(year: 2026, month: 2, day: 24, hour: 9))!
    let viewModel = await makeViewModel(
      [
        session(start: longAgo, seconds: 600, task: ref("old"), title: "Old Task"),
        session(start: today, seconds: 900, task: ref("new"), title: "New Task"),
      ], calendar: calendar, now: now)

    #expect(viewModel.taskRows.map(\.title) == ["New Task"])

    viewModel.scope = .thisMonth
    #expect(viewModel.taskRows.map(\.title) == ["New Task"])

    viewModel.scope = .allTime
    #expect(viewModel.taskRows.map(\.title) == ["New Task", "Old Task"])
  }

  @Test func taskRowsRankAndResolveProviderLabel() async {
    let earlier = Date(timeIntervalSinceReferenceDate: 100 * 86_400 + 12 * 3_600)
    let later = Date(timeIntervalSinceReferenceDate: 105 * 86_400 + 12 * 3_600)
    let viewModel = await makeViewModel(
      [
        session(start: earlier, seconds: 1_800, task: ref("a", "reminders"), title: "Task A"),
        session(start: later, seconds: 1_200, task: ref("a", "reminders"), title: "Task A"),
        session(start: earlier, seconds: 900, task: nil, title: nil),
      ],
      providerLabel: { ["reminders": "Reminders"][$0] ?? $0 })

    viewModel.scope = .allTime
    let rows = viewModel.taskRows
    #expect(rows.count == 2)

    let taskA = rows[0]
    #expect(taskA.title == "Task A")
    #expect(taskA.providerLabel == "Reminders")
    #expect(taskA.totalSeconds == 3_000)
    #expect(taskA.lastSessionDate == later.addingTimeInterval(20 * 60))

    let untracked = rows[1]
    #expect(untracked.title == "Untracked")
    #expect(untracked.providerLabel == "—")
    #expect(untracked.taskRef == nil)
  }

  // MARK: - Fixtures

  private func ref(_ nativeID: String, _ provider: String = "local") -> TaskRef {
    TaskRef(providerID: ProviderID(provider), nativeID: nativeID)
  }

  private func session(
    start: Date, seconds: TimeInterval, task: TaskRef?, title: String?
  ) -> Session {
    Session(
      id: UUID(), phase: .focus, startedAt: start, endedAt: start.addingTimeInterval(seconds),
      wasCompleted: true,
      segments: [FocusSegment(id: UUID(), taskRef: task, taskTitle: title, seconds: seconds)])
  }

  private func makeViewModel(
    _ sessions: [Session], calendar: Calendar? = nil, now: Date? = nil,
    providerLabel: @escaping (String) -> String = { $0 }
  ) async -> StatsViewModel {
    let store = SessionStore(repository: FakeSessionRepository(sessions: sessions))
    await store.reload()
    return StatsViewModel(
      store: store, providerLabel: providerLabel,
      calendarProvider: { calendar ?? .current }, nowProvider: { now ?? Date() })
  }
}
