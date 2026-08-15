//
//  StatsViewModelTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

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
    start: Date, seconds: TimeInterval = 1_500, completed: Bool = true,
    provider: ProviderID? = nil, nativeID: String = "t1", title: String? = nil,
    providerLabel: String? = nil, providerTint: ProviderTint? = nil
  ) -> Session {
    let ref = provider.map { TaskRef(providerID: $0, nativeID: nativeID) }
    let segment = FocusSegment(
      id: UUID(), taskRef: ref, taskTitle: title, seconds: seconds, providerLabel: providerLabel,
      providerTint: providerTint)
    return Session(
      id: UUID(), phase: .focus, startedAt: start,
      endedAt: start.addingTimeInterval(seconds),
      wasCompleted: completed, segments: [segment])
  }

  private func makeViewModel(
    _ sessions: [Session], providerLabel: @escaping (String) -> String = { $0 },
    providerTint: @escaping (String) -> ProviderTint = { _ in .gray }
  ) async -> StatsViewModel {
    let store = SessionStore(repository: FakeSessionRepository(sessions: sessions))
    await store.reload()
    return StatsViewModel(store: store, providerLabel: providerLabel, providerTint: providerTint)
  }

  // MARK: - Empty store

  @Test func emptyStore() async {
    let viewModel = await makeViewModel([])
    #expect(viewModel.isEmpty)
    #expect(viewModel.todayFocusCount == 0)
    #expect(viewModel.todayFocusSeconds == 0)
    #expect(viewModel.currentStreak == 0)
    #expect(viewModel.statCards.focusCount == 0)
    #expect(viewModel.statCards.taskBreakdown.isEmpty)
    #expect(viewModel.dailyFocusTotals.isEmpty)
    #expect(viewModel.providerBreakdown.isEmpty)
    #expect(viewModel.allTaskRows.isEmpty)
  }

  // MARK: - Single session

  @Test func singleSessionToday() async {
    let start = Self.dayStart(daysAgo: 0).addingTimeInterval(9 * 3_600)
    let viewModel = await makeViewModel([focus(start: start, seconds: 1_500, provider: "local")])

    #expect(!viewModel.isEmpty)
    #expect(viewModel.todayFocusCount == 1)
    #expect(viewModel.todayFocusSeconds == 1_500)
    #expect(viewModel.currentStreak == 1)
    #expect(viewModel.statCards.focusCount == 1)
    #expect(viewModel.statCards.taskBreakdown.count == 1)
    #expect(viewModel.allTaskRows.count == 1)
  }

  @Test func incompleteAndBreakSessionsIgnoredForFocus() async {
    let start = Self.dayStart(daysAgo: 0).addingTimeInterval(9 * 3_600)
    let viewModel = await makeViewModel([
      focus(start: start, completed: false),
      Session(
        id: UUID(), phase: .shortBreak, startedAt: start, endedAt: start.addingTimeInterval(300),
        wasCompleted: true),
    ])
    #expect(viewModel.todayFocusCount == 0)
    #expect(viewModel.currentStreak == 0)
    #expect(viewModel.statCards.focusCount == 0)
  }

  // MARK: - Count vs. time split (D5 of design doc 0010)

  @Test func incompleteFocusSessionStillCreditsTodayFocusSeconds() async {
    let start = Self.dayStart(daysAgo: 0).addingTimeInterval(9 * 3_600)
    let viewModel = await makeViewModel([
      focus(start: start, seconds: 600, completed: false, provider: "local")
    ])
    #expect(viewModel.todayFocusCount == 0)
    #expect(viewModel.todayFocusSeconds == 600)
  }

  @Test func incompleteFocusSessionStillAppearsInBreakdowns() async {
    let day = Self.fixedNoon(day: 400)
    let viewModel = await makeViewModel([
      focus(
        start: day, seconds: 720, completed: false, provider: "local", nativeID: "abc",
        title: "Draft")
    ])
    viewModel.scope = .allTime

    #expect(viewModel.statCards.focusCount == 0)
    #expect(viewModel.statCards.focusSeconds == 720)
    #expect(viewModel.statCards.taskBreakdown.first?.seconds == 720.0)
    #expect(viewModel.providerBreakdown.first?.seconds == 720)
    #expect(viewModel.dailyFocusTotals.first?.seconds == 720)
    #expect(viewModel.allTaskRows.first?.totalSeconds == 720)
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
        focus(start: day, seconds: 3_000, provider: "reminders", nativeID: "a", title: "A"),
        focus(start: day, seconds: 1_500, provider: "obsidian", nativeID: "b", title: "B"),
        focus(start: day, seconds: 600, provider: nil, title: nil),
      ],
      providerLabel: { ["reminders": "Reminders", "obsidian": "Obsidian"][$0] ?? $0 })

    viewModel.scope = .allTime
    let breakdown = viewModel.providerBreakdown
    #expect(breakdown.map(\.seconds) == [3_000, 1_500, 600])
    #expect(breakdown.map(\.label) == ["Reminders", "Obsidian", "Untracked"])
  }

  @Test func allTaskRowsRankAndResolveProviderLabel() async {
    let earlier = Self.fixedNoon(day: 100)
    let later = Self.fixedNoon(day: 105)
    let viewModel = await makeViewModel(
      [
        focus(
          start: earlier, seconds: 1_800, provider: "reminders", nativeID: "a", title: "Task A"),
        focus(start: later, seconds: 1_200, provider: "reminders", nativeID: "a", title: "Task A"),
        focus(start: earlier, seconds: 900, provider: nil, title: nil),
      ],
      providerLabel: { ["reminders": "Reminders"][$0] ?? $0 })

    viewModel.scope = .allTime
    let rows = viewModel.allTaskRows
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

  @Test func dailyFocusTotalsGroupByDayAndProvider() async {
    let dayOne = Self.fixedNoon(day: 200)
    let dayTwo = Self.fixedNoon(day: 201)
    let viewModel = await makeViewModel([
      focus(start: dayOne, seconds: 1_500, provider: "local"),
      focus(start: dayOne, seconds: 1_500, provider: "local"),
      focus(start: dayTwo, seconds: 1_500, provider: "local"),
      focus(start: dayTwo, seconds: 600, provider: nil),
    ])

    viewModel.scope = .allTime
    let totals = viewModel.dailyFocusTotals
    // day one: one local bucket (3_000s); day two: local (1_500s) + untracked (600s)
    #expect(totals.count == 3)
    let localDayOne = totals.first { Self.calendar.isDate($0.day, inSameDayAs: dayOne) }
    #expect(localDayOne?.seconds == 3_000)
    let untrackedDayTwo = totals.first {
      $0.providerID == "__untracked__" && Self.calendar.isDate($0.day, inSameDayAs: dayTwo)
    }
    #expect(untrackedDayTwo?.seconds == 600)
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
        focus(start: day, seconds: 1_500, provider: "local"),
        focus(start: day, seconds: 600, provider: nil),
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

  // MARK: - Provider cosmetics snapshot (ADR-0010, D4)

  @Test func snapshotResolvesWhenProviderIsAbsentFromTheLiveRegistry() async {
    let day = Self.fixedNoon(day: 500)
    let viewModel = await makeViewModel([
      focus(
        start: day, seconds: 1_500, provider: "obsidian", nativeID: "a", title: "Task A",
        providerLabel: "Obsidian", providerTint: .purple)
    ])
    viewModel.scope = .allTime

    let breakdown = viewModel.providerBreakdown
    #expect(breakdown.first?.label == "Obsidian")
    #expect(breakdown.first?.tint == .purple)

    let totals = viewModel.dailyFocusTotals
    #expect(totals.first?.tint == .purple)

    let rows = viewModel.allTaskRows
    #expect(rows.first?.providerLabel == "Obsidian")
  }

  @Test func snapshotMatchesLiveRegistryWhenProviderIsPresent() async {
    let day = Self.fixedNoon(day: 501)
    let viewModel = await makeViewModel(
      [
        focus(
          start: day, seconds: 1_500, provider: "obsidian", nativeID: "a", title: "Task A",
          providerLabel: "Obsidian", providerTint: .purple)
      ],
      providerLabel: { ["obsidian": "Obsidian"][$0] ?? $0 },
      providerTint: { ["obsidian": ProviderTint.purple][$0] ?? .gray })
    viewModel.scope = .allTime

    let breakdown = viewModel.providerBreakdown
    #expect(breakdown.first?.label == "Obsidian")
    #expect(breakdown.first?.tint == .purple)
  }

  @Test func legacySnapshotlessSegmentsStillResolveThroughTheLiveRegistry() async {
    let day = Self.fixedNoon(day: 502)
    let viewModel = await makeViewModel(
      [focus(start: day, seconds: 1_500, provider: "reminders", nativeID: "a", title: "Task A")],
      providerLabel: { ["reminders": "Reminders"][$0] ?? $0 },
      providerTint: { ["reminders": ProviderTint.orange][$0] ?? .gray })
    viewModel.scope = .allTime

    let breakdown = viewModel.providerBreakdown
    #expect(breakdown.first?.label == "Reminders")
    #expect(breakdown.first?.tint == .orange)
  }

  @Test func latestSnapshotWinsAcrossSessions() async {
    let earlier = Self.fixedNoon(day: 503)
    let later = Self.fixedNoon(day: 504)
    let viewModel = await makeViewModel([
      focus(
        start: earlier, seconds: 1_500, provider: "obsidian", nativeID: "a", title: "Task A",
        providerLabel: "Old Name", providerTint: .green),
      focus(
        start: later, seconds: 1_500, provider: "obsidian", nativeID: "a", title: "Task A",
        providerLabel: "New Name", providerTint: .purple),
    ])
    viewModel.scope = .allTime

    let breakdown = viewModel.providerBreakdown
    #expect(breakdown.first?.label == "New Name")
    #expect(breakdown.first?.tint == .purple)
  }

  // MARK: - Live updates via the store

  @Test func storeAppendUpdatesTodayCounts() async {
    let store = SessionStore(repository: FakeSessionRepository())
    await store.reload()
    let viewModel = StatsViewModel(store: store)
    #expect(viewModel.todayFocusCount == 0)

    let start = Self.dayStart(daysAgo: 0).addingTimeInterval(9 * 3_600)
    store.append(focus(start: start, seconds: 1_500, provider: "local"))

    #expect(viewModel.todayFocusCount == 1)
    #expect(viewModel.todayFocusSeconds == 1_500)
    #expect(viewModel.currentStreak == 1)
  }

  // MARK: - Sub-minute durations (issue #579)

  @Test func subMinuteFocusSessionCreditsSecondsWithoutFlooring() async {
    let start = Self.dayStart(daysAgo: 0).addingTimeInterval(9 * 3_600)
    let viewModel = await makeViewModel([
      focus(start: start, seconds: 45, completed: false, provider: "local")
    ])
    #expect(viewModel.todayFocusSeconds == 45)
    #expect(viewModel.dailyFocusTotals.first?.seconds == 45)
  }

  @Test func subMinuteFocusSessionOutranksLongerFlooredZeroWouldHaveHidden() async {
    let day = Self.fixedNoon(day: 600)
    let viewModel = await makeViewModel(
      [
        focus(
          start: day, seconds: 45, completed: false, provider: "local", nativeID: "short",
          title: "Short"),
        focus(
          start: day, seconds: 20, completed: false, provider: "reminders", nativeID: "shorter",
          title: "Shorter"),
      ],
      providerLabel: { ["local": "Local", "reminders": "Reminders"][$0] ?? $0 })
    viewModel.scope = .allTime

    let rows = viewModel.allTaskRows
    #expect(rows.map(\.title) == ["Short", "Shorter"])
    #expect(rows.map(\.totalSeconds) == [45, 20])

    let breakdown = viewModel.providerBreakdown
    #expect(breakdown.map(\.label) == ["Local", "Reminders"])
    #expect(breakdown.map(\.seconds) == [45, 20])
  }
}
