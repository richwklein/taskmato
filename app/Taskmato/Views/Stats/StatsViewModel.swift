//
//  StatsViewModel.swift
//  Taskmato
//

import Foundation
import Observation

/// The single owner of stats scope state, period navigation, and all session aggregation.
///
/// Projects every value the stats UI and popover footer consume over an injected
/// ``SessionStore``'s observable session log. All grouping, counting, and streak logic lives
/// here — never in the store (design doc 0006, decisions D1/D2).
@Observable
@MainActor
final class StatsViewModel {

  /// Grouping key used for focus time recorded without a selected task.
  private static let untrackedKey = "__untracked__"

  private let store: SessionStore
  private let providerLabel: (String) -> String
  private let providerTint: (String) -> ProviderTint
  private let calendarProvider: () -> Calendar
  private let nowProvider: () -> Date

  /// Calendar snapshot shared by every Stats calculation until the next temporal refresh.
  private var calendar: Calendar

  /// Clock snapshot shared by every Stats calculation until the next temporal refresh.
  private var now: Date

  /// Retains the notification observers that invalidate the snapshots above.
  private var temporalObserver: StatsTemporalObserver?

  /// The full session log, oldest-first; the source for every derived value.
  private var sessions: [Session] { store.sessions }

  /// The time window the scope-dependent outputs are computed over.
  var scope: StatScope = .today {
    didSet { offset = 0 }
  }

  /// Period offset: `0` is the current period, `-1` the previous, and so on.
  private(set) var offset = 0

  /// Creates a view model that projects over a session store.
  /// - Parameters:
  ///   - store: The session log to aggregate.
  ///   - providerLabel: Resolves a `providerID` to a display name; defaults to the raw ID.
  ///   - providerTint: Resolves a `providerID` to a display color; defaults to ``ProviderTint/gray``.
  ///   - calendarProvider: Supplies the user's current calendar for deterministic time tests.
  ///   - nowProvider: Supplies the current date for deterministic time tests.
  init(
    store: SessionStore,
    providerLabel: @escaping (String) -> String = { $0 },
    providerTint: @escaping (String) -> ProviderTint = { _ in .gray },
    calendarProvider: @escaping () -> Calendar = { .current },
    nowProvider: @escaping () -> Date = Date.init
  ) {
    self.store = store
    self.providerLabel = providerLabel
    self.providerTint = providerTint
    self.calendarProvider = calendarProvider
    self.nowProvider = nowProvider
    self.calendar = calendarProvider()
    self.now = nowProvider()
  }

  // MARK: - Navigation

  /// Moves one period into the past.
  func navigateBack() { offset -= 1 }

  /// Moves one period toward the present, never past the current period.
  func navigateForward() { if offset < 0 { offset += 1 } }

  /// Whether a later period exists to navigate to.
  var canNavigateForward: Bool { offset < 0 }

  /// Whether period navigation applies; always hidden for all-time.
  var canNavigateBack: Bool { scope != .allTime }

  /// The date range the current scope and offset resolve to, for the navigation label.
  var currentInterval: DateInterval { scopedInterval }

  // MARK: - Aggregated outputs

  /// Whether any sessions have been recorded at all.
  var isEmpty: Bool { sessions.isEmpty }

  /// Summary stat cards for the current scope and period.
  var statCards: SessionSummary { SessionSummary(sessions: sessions, over: scopedInterval) }

  /// Begins refreshing the snapshots on activation, locale, time-zone, and day-rollover changes.
  func startObservingTemporalChanges() {
    temporalObserver = StatsTemporalObserver(stats: self)
  }

  /// Invalidates time-dependent projections after activation or a system calendar change.
  func refreshTemporalContext() {
    calendar = calendarProvider()
    now = nowProvider()
  }

  /// The calendar snapshot used by all current Stats projections.
  var currentCalendar: Calendar { calendar }

  /// The clock snapshot used by all current Stats projections.
  var currentDate: Date { now }

  /// Focus seconds per day, split by provider, within the current scope.
  ///
  /// A time metric (D5 of design doc 0010): sums every focus segment regardless of the owning
  /// phase's completion, so a stopped or skipped phase's invested time still appears.
  var dailyFocusTotals: [DayTotal] {
    var order: [String] = []
    var accumulated: [String: DayBucket] = [:]

    for session in focusSessions(in: scopedInterval) {
      let day = calendar.startOfDay(for: session.startedAt)
      for segment in session.segments {
        let providerID = segment.taskRef?.providerID.rawValue ?? Self.untrackedKey
        let key = "\(day.timeIntervalSinceReferenceDate):\(providerID)"
        if accumulated[key] == nil {
          order.append(key)
          accumulated[key] = DayBucket(day: day, providerID: providerID, seconds: 0)
        }
        accumulated[key]!.seconds += segment.seconds
      }
    }

    let snapshots = providerSnapshots
    return
      order
      .compactMap { key -> DayTotal? in
        guard let entry = accumulated[key] else { return nil }
        return DayTotal(
          day: entry.day, providerID: entry.providerID,
          tint: displayTint(for: entry.providerID, in: snapshots), seconds: entry.seconds
        )
      }
      .sorted { ($0.day, $0.providerID) < ($1.day, $1.providerID) }
  }

  /// Focus seconds per calendar week, split by provider, across the full history.
  ///
  /// Like the existing time metrics, this includes incomplete focus sessions and untracked
  /// segments while excluding breaks. Each segment belongs to the week containing its session's
  /// start, preserving ADR-0009's durable session-start attribution.
  var weeklyFocusTotals: [WeekTotal] {
    var accumulated: [String: WeekBucket] = [:]

    for session in sessions where session.phase == .focus {
      let week =
        calendar.dateInterval(of: .weekOfYear, for: session.startedAt)?.start
        ?? calendar.startOfDay(for: session.startedAt)
      for segment in session.segments {
        let providerID = segment.taskRef?.providerID.rawValue ?? Self.untrackedKey
        let key = "\(week.timeIntervalSinceReferenceDate):\(providerID)"
        if accumulated[key] == nil {
          accumulated[key] = WeekBucket(week: week, providerID: providerID, seconds: 0)
        }
        accumulated[key]!.seconds += segment.seconds
      }
    }

    let snapshots = providerSnapshots
    return accumulated.values.map { entry in
      WeekTotal(
        week: entry.week, providerID: entry.providerID,
        tint: displayTint(for: entry.providerID, in: snapshots), seconds: entry.seconds)
    }
    .sorted { ($0.week, $0.providerID) < ($1.week, $1.providerID) }
  }

  /// Providers represented by the all-time weekly chart, in a deterministic stacking order.
  var weeklyFocusProviders: [ProviderSlice] {
    let totals = weeklyFocusTotals
    let secondsByProvider = totals.reduce(into: [String: TimeInterval]()) {
      $0[$1.providerID, default: 0] += $1.seconds
    }
    let snapshots = providerSnapshots
    return secondsByProvider.keys.sorted().compactMap { providerID in
      guard let seconds = secondsByProvider[providerID], seconds > 0 else { return nil }
      return ProviderSlice(
        providerID: providerID, label: displayLabel(for: providerID, in: snapshots),
        tint: displayTint(for: providerID, in: snapshots),
        seconds: seconds)
    }
  }

  /// Focus time by provider within the current scope, sorted by duration descending.
  ///
  /// A time metric (D5): sums every focus segment regardless of the owning phase's completion.
  var providerBreakdown: [ProviderSlice] {
    var order: [String] = []
    var accumulated: [String: TimeInterval] = [:]

    for session in focusSessions(in: scopedInterval) {
      for segment in session.segments {
        let providerID = segment.taskRef?.providerID.rawValue ?? Self.untrackedKey
        if accumulated[providerID] == nil { order.append(providerID) }
        accumulated[providerID, default: 0] += segment.seconds
      }
    }

    let snapshots = providerSnapshots
    return
      order
      .map { providerID in
        ProviderSlice(
          providerID: providerID,
          label: displayLabel(for: providerID, in: snapshots),
          tint: displayTint(for: providerID, in: snapshots),
          seconds: accumulated[providerID] ?? 0)
      }
      .sorted { $0.seconds > $1.seconds }
  }

  /// Every task's focus totals within the current scope, ranked by focus time descending.
  ///
  /// A time metric (D5): sums every focus segment regardless of the owning phase's completion.
  /// All Time resolves to an unbounded interval, so that scope sees the whole log.
  var taskRows: [StatsTaskRow] {
    var order: [String] = []
    var accumulated: [String: TaskBucket] = [:]
    let snapshots = providerSnapshots

    for session in focusSessions(in: scopedInterval) {
      for segment in session.segments {
        let key: String
        if let ref = segment.taskRef {
          key = "\(ref.providerID.rawValue):\(ref.nativeID)"
        } else {
          key = Self.untrackedKey
        }
        if accumulated[key] == nil {
          order.append(key)
          accumulated[key] = TaskBucket(
            taskRef: segment.taskRef, title: segment.taskTitle ?? "Untracked", seconds: 0,
            last: session.endedAt)
        }
        accumulated[key]!.seconds += segment.seconds
        if session.endedAt > accumulated[key]!.last { accumulated[key]!.last = session.endedAt }
      }
    }

    return
      order
      .compactMap { key -> StatsTaskRow? in
        guard let entry = accumulated[key] else { return nil }
        let resolvedLabel =
          entry.taskRef.map { displayLabel(for: $0.providerID.rawValue, in: snapshots) } ?? "—"
        return StatsTaskRow(
          taskRef: entry.taskRef, title: entry.title, providerLabel: resolvedLabel,
          totalSeconds: entry.seconds, lastSessionDate: entry.last)
      }
      .sorted { $0.totalSeconds > $1.totalSeconds }
  }

  /// Consecutive calendar days ending today (or yesterday, as a grace) with ≥1 completed focus
  /// session. A count metric (D5): the pomodoro is indivisible, so a stopped or skipped phase
  /// does not extend the streak.
  var currentStreak: Int {
    let activeDays = Set(
      sessions
        .filter { $0.phase == .focus && $0.wasCompleted }
        .map { calendar.startOfDay(for: $0.startedAt) })
    guard !activeDays.isEmpty else { return 0 }

    let today = calendar.startOfDay(for: now)
    var cursor = today
    if !activeDays.contains(cursor) {
      guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
        activeDays.contains(yesterday)
      else { return 0 }
      cursor = yesterday
    }

    var streak = 0
    while activeDays.contains(cursor) {
      streak += 1
      guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
      cursor = previous
    }
    return streak
  }

  /// Number of completed focus sessions that started today. A count metric (D5): gated on
  /// `wasCompleted` — the pomodoro is indivisible.
  var todayFocusCount: Int { todaysCompletedFocus.count }

  /// Total seconds across focus segments recorded today, regardless of the owning phase's
  /// completion. A time metric (D5): a stopped or skipped phase still contributes.
  var todayFocusSeconds: TimeInterval {
    todaysFocus.flatMap(\.segments).reduce(0) { $0 + $1.seconds }
  }

  // MARK: - Private

  /// Mutable accumulator for one `(day, provider)` bucket while building `dailyFocusTotals`.
  private struct DayBucket {
    let day: Date
    let providerID: String
    var seconds: TimeInterval
  }

  /// Mutable accumulator for one `(week, provider)` bucket while building `weeklyFocusTotals`.
  private struct WeekBucket {
    let week: Date
    let providerID: String
    var seconds: TimeInterval
  }

  /// Mutable accumulator for one task while building `taskRows`.
  private struct TaskBucket {
    let taskRef: TaskRef?
    let title: String
    var seconds: TimeInterval
    var last: Date
  }

  /// Latest provider cosmetics snapshot per provider id, harvested from segment snapshots.
  ///
  /// Sessions arrive oldest-first, so the last non-`nil` snapshot seen for a provider — the most
  /// recent — wins if a provider's name or tint ever differs across records.
  private struct ProviderSnapshots {
    private var labels: [String: String] = [:]
    private var tints: [String: ProviderTint] = [:]

    init(sessions: [Session]) {
      for session in sessions {
        for segment in session.segments {
          guard let providerID = segment.taskRef?.providerID.rawValue else { continue }
          if let label = segment.providerLabel { labels[providerID] = label }
          if let tint = segment.providerTint { tints[providerID] = tint }
        }
      }
    }

    /// The most recent snapshot label recorded for `providerID`, if any.
    func label(for providerID: String) -> String? { labels[providerID] }

    /// The most recent snapshot tint recorded for `providerID`, if any.
    func tint(for providerID: String) -> ProviderTint? { tints[providerID] }
  }

  /// Snapshots harvested from the full log, so a provider absent from the current period still
  /// resolves.
  private var providerSnapshots: ProviderSnapshots { ProviderSnapshots(sessions: sessions) }

  /// Focus sessions that started today (calendar day, local time zone), regardless of
  /// completion — the population time metrics sum over.
  private var todaysFocus: [Session] {
    let today = calendar.startOfDay(for: now)
    return sessions.filter {
      $0.phase == .focus && calendar.startOfDay(for: $0.startedAt) == today
    }
  }

  /// Completed focus sessions that started today — the population count metrics gate on.
  private var todaysCompletedFocus: [Session] {
    todaysFocus.filter(\.wasCompleted)
  }

  /// Focus sessions whose start falls within `interval` (half-open), regardless of
  /// completion — the population time metrics sum over (D5 of design doc 0010).
  private func focusSessions(in interval: DateInterval) -> [Session] {
    sessions.filter {
      $0.phase == .focus && $0.startedAt >= interval.start && $0.startedAt < interval.end
    }
  }

  /// Display label for a provider grouping key: the record's snapshot first, then the live
  /// registry closure, so a ported record renders correctly with the provider absent (D4).
  private func displayLabel(for providerID: String, in snapshots: ProviderSnapshots) -> String {
    guard providerID != Self.untrackedKey else { return "Untracked" }
    return snapshots.label(for: providerID) ?? providerLabel(providerID)
  }

  /// Display color for a provider grouping key: snapshot first, then the live registry closure;
  /// gray for the untracked sentinel.
  private func displayTint(
    for providerID: String, in snapshots: ProviderSnapshots
  ) -> ProviderTint {
    guard providerID != Self.untrackedKey else { return .gray }
    return snapshots.tint(for: providerID) ?? providerTint(providerID)
  }

  /// The date range the scope-dependent outputs are computed over, honoring `offset`.
  private var scopedInterval: DateInterval {
    switch scope {
    case .today:
      let base = calendar.startOfDay(for: now)
      let start = calendar.date(byAdding: .day, value: offset, to: base) ?? base
      let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
      return DateInterval(start: start, end: end)
    case .thisWeek:
      let todayEnd =
        calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
        ?? now
      let end = calendar.date(byAdding: .day, value: 7 * offset, to: todayEnd) ?? todayEnd
      let start = calendar.date(byAdding: .day, value: -7, to: end) ?? end
      return DateInterval(start: start, end: end)
    case .thisMonth:
      let monthStart =
        calendar.date(from: calendar.dateComponents([.year, .month], from: now))
        ?? calendar.startOfDay(for: now)
      let start = calendar.date(byAdding: .month, value: offset, to: monthStart) ?? monthStart
      let end = calendar.date(byAdding: .month, value: 1, to: start) ?? start
      return DateInterval(start: start, end: end)
    case .allTime:
      return DateInterval(start: .distantPast, end: .distantFuture)
    }
  }
}

#if DEBUG
  extension StatsViewModel {

    /// Sample provider display names and tints used by the seeded preview.
    private static let previewProviders: [String: (label: String, tint: ProviderTint)] = [
      "local": ("Local", .green),
      "reminders": ("Reminders", .orange),
      "obsidian": ("Obsidian", .purple),
    ]

    /// A view model backed by an empty throwaway temp-file repository, for SwiftUI previews.
    static var preview: StatsViewModel {
      seeded([])
    }

    /// A view model seeded with two weeks of sample sessions across providers.
    static var previewSeeded: StatsViewModel {
      let calendar = Calendar.current
      let today = calendar.startOfDay(for: Date())
      let providers = ["local", "reminders", "obsidian", nil]
      var sessions: [Session] = []
      for dayOffset in 0..<14 {
        guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: today) else {
          continue
        }
        for slot in 0...(dayOffset % 3) {
          let provider = providers[(dayOffset + slot) % providers.count]
          let start = day.addingTimeInterval(TimeInterval((9 + slot) * 3_600))
          let ref = provider.map { TaskRef(providerID: ProviderID($0), nativeID: "task-\(slot)") }
          let end = start.addingTimeInterval(25 * 60)
          let segment = FocusSegment(
            id: UUID(), taskRef: ref, taskTitle: provider.map { "\($0.capitalized) task \(slot)" },
            seconds: end.timeIntervalSince(start))
          sessions.append(
            Session(
              id: UUID(), phase: .focus, startedAt: start,
              endedAt: end, wasCompleted: true, segments: [segment]))
        }
      }

      // A ~45s incomplete session on today, so the sub-minute path is visible in previews.
      let shortStart = today.addingTimeInterval(8 * 3_600)
      let shortEnd = shortStart.addingTimeInterval(45)
      let shortSegment = FocusSegment(
        id: UUID(), taskRef: TaskRef(providerID: ProviderID("local"), nativeID: "task-short"),
        taskTitle: "Local task short", seconds: shortEnd.timeIntervalSince(shortStart))
      sessions.append(
        Session(
          id: UUID(), phase: .focus, startedAt: shortStart,
          endedAt: shortEnd, wasCompleted: false, segments: [shortSegment]))

      return seeded(sessions)
    }

    /// Builds a preview view model seeded with `sessions`.
    private static func seeded(_ sessions: [Session]) -> StatsViewModel {
      StatsViewModel(
        store: .seeded(sessions),
        providerLabel: { previewProviders[$0]?.label ?? $0 },
        providerTint: { previewProviders[$0]?.tint ?? .gray })
    }
  }
#endif
