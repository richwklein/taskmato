//
//  StatsViewModelTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

/// In-memory repository seeded with fixed sessions; stands in for the SwiftData fixture
/// that #402 will make extractable.
@MainActor
private final class FakeSessionRepository: SessionRepository {

  private var stored: [Session]

  init(sessions: [Session]) { self.stored = sessions }

  func sessions(over interval: DateInterval) async throws -> [Session] {
    stored.filter { interval.contains($0.startedAt) }
  }

  func append(_ session: Session) async throws { stored.append(session) }
}

@MainActor
struct StatsViewModelTests {

  // MARK: - Fixtures

  private static let calendar = Calendar.current

  /// Midnight (local) `days` before today.
  private static func dayStart(daysAgo days: Int) -> Date {
    let today = calendar.startOfDay(for: Date())
    return calendar.date(byAdding: .day, value: -days, to: today) ?? today
  }

  /// A fixed absolute noon `days` after the reference date, for scope-independent grouping.
  private static func fixedNoon(day: Int) -> Date {
    Date(timeIntervalSinceReferenceDate: TimeInterval(day * 86_400 + 12 * 3_600))
  }

  private func focus(
    start: Date, minutes: Int = 25, completed: Bool = true,
    provider: String? = nil, nativeID: String = "t1", title: String? = nil
  ) -> Session {
    let ref = provider.map { TaskRef(providerID: $0, nativeID: nativeID) }
    return Session(
      id: UUID(), phase: .focus, startedAt: start,
      endedAt: start.addingTimeInterval(TimeInterval(minutes * 60)),
      wasCompleted: completed, taskRef: ref, taskTitle: title)
  }

  private func makeViewModel(
    _ sessions: [Session], providerLabel: @escaping (String) -> String = { $0 },
    providerTint: @escaping (String) -> ProviderTint = { _ in .gray }
  ) async -> StatsViewModel {
    let viewModel = StatsViewModel(
      repository: FakeSessionRepository(sessions: sessions), providerLabel: providerLabel,
      providerTint: providerTint)
    await viewModel.refresh()
    return viewModel
  }

  // MARK: - Empty store

  @Test func emptyStore() async {
    let viewModel = await makeViewModel([])
    #expect(viewModel.isEmpty)
    #expect(viewModel.todayFocusCount == 0)
    #expect(viewModel.todayFocusMinutes == 0)
    #expect(viewModel.currentStreak == 0)
    #expect(viewModel.statCards.focusCount == 0)
    #expect(viewModel.taskBreakdown.isEmpty)
    #expect(viewModel.dailyFocusTotals.isEmpty)
    #expect(viewModel.providerBreakdown.isEmpty)
    #expect(viewModel.allTaskRows.isEmpty)
  }

  // MARK: - Single session

  @Test func singleSessionToday() async {
    let start = Self.dayStart(daysAgo: 0).addingTimeInterval(9 * 3_600)
    let viewModel = await makeViewModel([focus(start: start, minutes: 25, provider: "local")])

    #expect(!viewModel.isEmpty)
    #expect(viewModel.todayFocusCount == 1)
    #expect(viewModel.todayFocusMinutes == 25)
    #expect(viewModel.currentStreak == 1)
    #expect(viewModel.statCards.focusCount == 1)
    #expect(viewModel.taskBreakdown.count == 1)
    #expect(viewModel.allTaskRows.count == 1)
  }

  @Test func incompleteAndBreakSessionsIgnoredForFocus() async {
    let start = Self.dayStart(daysAgo: 0).addingTimeInterval(9 * 3_600)
    let viewModel = await makeViewModel([
      focus(start: start, completed: false),
      Session(
        id: UUID(), phase: .shortBreak, startedAt: start, endedAt: start.addingTimeInterval(300),
        wasCompleted: true, taskRef: nil, taskTitle: nil),
    ])
    #expect(viewModel.todayFocusCount == 0)
    #expect(viewModel.currentStreak == 0)
    #expect(viewModel.statCards.focusCount == 0)
  }

  // MARK: - Multi-day window scoping

  @Test func todayScopeExcludesYesterday() async {
    let today = Self.dayStart(daysAgo: 0).addingTimeInterval(9 * 3_600)
    let yesterday = Self.dayStart(daysAgo: 1).addingTimeInterval(9 * 3_600)
    let viewModel = await makeViewModel([
      focus(start: today, provider: "local"),
      focus(start: yesterday, provider: "local"),
    ])

    viewModel.scope = .today
    #expect(viewModel.statCards.focusCount == 1)

    viewModel.scope = .thisWeek
    #expect(viewModel.statCards.focusCount == 2)
  }

  @Test func offsetShiftsTodayWindowToYesterday() async {
    let yesterday = Self.dayStart(daysAgo: 1).addingTimeInterval(9 * 3_600)
    let viewModel = await makeViewModel([focus(start: yesterday, provider: "local")])

    viewModel.scope = .today
    #expect(viewModel.statCards.focusCount == 0)

    viewModel.navigateBack()
    #expect(viewModel.statCards.focusCount == 1)
  }

  // MARK: - Time-zone / day boundary

  @Test func midnightSessionCountsTowardToday() async {
    let midnight = Self.dayStart(daysAgo: 0)
    let viewModel = await makeViewModel([focus(start: midnight, provider: "local")])

    #expect(viewModel.todayFocusCount == 1)
    viewModel.scope = .today
    #expect(viewModel.statCards.focusCount == 1)
  }

  // MARK: - Streak

  @Test func streakStopsAtGap() async {
    let viewModel = await makeViewModel([
      focus(start: Self.dayStart(daysAgo: 0).addingTimeInterval(3_600)),
      focus(start: Self.dayStart(daysAgo: 1).addingTimeInterval(3_600)),
      // gap on day 2
      focus(start: Self.dayStart(daysAgo: 3).addingTimeInterval(3_600)),
    ])
    #expect(viewModel.currentStreak == 2)
  }

  @Test func streakGraceWhenTodayEmpty() async {
    let viewModel = await makeViewModel([
      focus(start: Self.dayStart(daysAgo: 1).addingTimeInterval(3_600)),
      focus(start: Self.dayStart(daysAgo: 2).addingTimeInterval(3_600)),
    ])
    #expect(viewModel.currentStreak == 2)
  }

  @Test func streakZeroWhenLatestIsTwoDaysAgo() async {
    let viewModel = await makeViewModel([
      focus(start: Self.dayStart(daysAgo: 2).addingTimeInterval(3_600))
    ])
    #expect(viewModel.currentStreak == 0)
  }

  // MARK: - Offset navigation per scope

  @Test func navigationBoundsPerScope() async {
    let viewModel = await makeViewModel([])

    for scope in [StatScope.today, .thisWeek, .thisMonth] {
      viewModel.scope = scope
      #expect(viewModel.offset == 0)
      #expect(viewModel.canNavigateBack)
      #expect(!viewModel.canNavigateForward)

      viewModel.navigateBack()
      #expect(viewModel.offset == -1)
      #expect(viewModel.canNavigateForward)

      viewModel.navigateForward()
      #expect(viewModel.offset == 0)
      viewModel.navigateForward()  // never past current period
      #expect(viewModel.offset == 0)
    }

    viewModel.scope = .allTime
    #expect(!viewModel.canNavigateBack)
  }

  @Test func changingScopeResetsOffset() async {
    let viewModel = await makeViewModel([])
    viewModel.scope = .thisWeek
    viewModel.navigateBack()
    viewModel.navigateBack()
    #expect(viewModel.offset == -2)

    viewModel.scope = .thisMonth
    #expect(viewModel.offset == 0)
  }

  // MARK: - Aggregation grouping and labels (all-time scope)

  @Test func providerBreakdownRanksAndLabels() async {
    let day = Self.fixedNoon(day: 100)
    let viewModel = await makeViewModel(
      [
        focus(start: day, minutes: 50, provider: "reminders", nativeID: "a", title: "A"),
        focus(start: day, minutes: 25, provider: "obsidian", nativeID: "b", title: "B"),
        focus(start: day, minutes: 10, provider: nil, title: nil),
      ],
      providerLabel: { ["reminders": "Reminders", "obsidian": "Obsidian"][$0] ?? $0 })

    viewModel.scope = .allTime
    let breakdown = viewModel.providerBreakdown
    #expect(breakdown.map(\.minutes) == [50, 25, 10])
    #expect(breakdown.map(\.label) == ["Reminders", "Obsidian", "Untracked"])
  }

  @Test func allTaskRowsRankAndResolveProviderLabel() async {
    let earlier = Self.fixedNoon(day: 100)
    let later = Self.fixedNoon(day: 105)
    let viewModel = await makeViewModel(
      [
        focus(start: earlier, minutes: 30, provider: "reminders", nativeID: "a", title: "Task A"),
        focus(start: later, minutes: 20, provider: "reminders", nativeID: "a", title: "Task A"),
        focus(start: earlier, minutes: 15, provider: nil, title: nil),
      ],
      providerLabel: { ["reminders": "Reminders"][$0] ?? $0 })

    viewModel.scope = .allTime
    let rows = viewModel.allTaskRows
    #expect(rows.count == 2)

    let taskA = rows[0]
    #expect(taskA.title == "Task A")
    #expect(taskA.providerLabel == "Reminders")
    #expect(taskA.totalMinutes == 50)
    #expect(taskA.lastSessionDate == later.addingTimeInterval(20 * 60))

    let untracked = rows[1]
    #expect(untracked.title == "Untracked")
    #expect(untracked.providerLabel == "—")
    #expect(untracked.taskRef == nil)
  }

  @Test func dailyFocusTotalsGroupByDayAndProvider() async {
    let dayOne = Self.fixedNoon(day: 200)
    let dayTwo = Self.fixedNoon(day: 201)
    let viewModel = await makeViewModel([
      focus(start: dayOne, minutes: 25, provider: "local"),
      focus(start: dayOne, minutes: 25, provider: "local"),
      focus(start: dayTwo, minutes: 25, provider: "local"),
      focus(start: dayTwo, minutes: 10, provider: nil),
    ])

    viewModel.scope = .allTime
    let totals = viewModel.dailyFocusTotals
    // day one: one local bucket (50); day two: local (25) + untracked (10)
    #expect(totals.count == 3)
    let localDayOne = totals.first { Self.calendar.isDate($0.day, inSameDayAs: dayOne) }
    #expect(localDayOne?.minutes == 50)
    let untrackedDayTwo = totals.first {
      $0.providerID == "__untracked__" && Self.calendar.isDate($0.day, inSameDayAs: dayTwo)
    }
    #expect(untrackedDayTwo?.minutes == 10)
  }

  // MARK: - Current interval (navigation label)

  @Test func currentIntervalTracksScopeAndOffset() async {
    let viewModel = await makeViewModel([])
    let cal = Self.calendar
    let today = cal.startOfDay(for: Date())

    viewModel.scope = .today
    #expect(viewModel.currentInterval.start == today)
    #expect(viewModel.currentInterval.end == cal.date(byAdding: .day, value: 1, to: today))

    viewModel.navigateBack()
    let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
    #expect(viewModel.currentInterval.start == yesterday)
    #expect(viewModel.currentInterval.end == today)

    viewModel.scope = .allTime
    #expect(viewModel.currentInterval.start == .distantPast)
    #expect(viewModel.currentInterval.end == .distantFuture)
  }

  // MARK: - Provider tint resolution

  @Test func outputsCarryProviderTint() async {
    let day = Self.fixedNoon(day: 300)
    let viewModel = await makeViewModel(
      [
        focus(start: day, minutes: 25, provider: "local"),
        focus(start: day, minutes: 10, provider: nil),
      ],
      providerTint: { ["local": ProviderTint.green][$0] ?? .gray })
    viewModel.scope = .allTime

    let providers = viewModel.providerBreakdown
    #expect(providers.first { $0.providerID == "local" }?.tint == .green)
    #expect(providers.first { $0.providerID == "__untracked__" }?.tint == .gray)

    let totals = viewModel.dailyFocusTotals
    #expect(totals.first { $0.providerID == "local" }?.tint == .green)
    #expect(totals.first { $0.providerID == "__untracked__" }?.tint == .gray)
  }

  // MARK: - Optimistic append

  @Test func recordAppendedUpdatesTodayCounts() async {
    let viewModel = await makeViewModel([])
    #expect(viewModel.todayFocusCount == 0)

    let start = Self.dayStart(daysAgo: 0).addingTimeInterval(9 * 3_600)
    viewModel.recordAppended(focus(start: start, minutes: 25, provider: "local"))

    #expect(viewModel.todayFocusCount == 1)
    #expect(viewModel.todayFocusMinutes == 25)
    #expect(viewModel.currentStreak == 1)
  }
}
