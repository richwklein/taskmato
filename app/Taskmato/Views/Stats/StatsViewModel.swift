//
//  StatsViewModel.swift
//  Taskmato
//

import Foundation
import Observation

/// The single owner of stats scope state, period navigation, and all session aggregation.
///
/// Loads the full session log from an injected ``SessionRepository`` into an in-memory cache
/// and derives every value the stats UI and popover footer consume. All grouping, counting,
/// and streak logic lives here — never in the repository (design doc 0006, decisions D1/D2).
@Observable
@MainActor
final class StatsViewModel {

  /// Grouping key used for focus time recorded without a selected task.
  private static let untrackedKey = "__untracked__"

  private let repository: SessionRepository
  private let providerLabel: (String) -> String
  private let providerTint: (String) -> ProviderTint

  /// The full session log, oldest-first; the source for every derived value.
  private var sessions: [Session] = []

  /// The time window the scope-dependent outputs are computed over.
  var scope: StatScope = .today {
    didSet { offset = 0 }
  }

  /// Period offset: `0` is the current period, `-1` the previous, and so on.
  private(set) var offset = 0

  /// Creates a view model backed by a repository.
  /// - Parameters:
  ///   - repository: The session log to aggregate.
  ///   - providerLabel: Resolves a `providerID` to a display name; defaults to the raw ID.
  ///   - providerTint: Resolves a `providerID` to a display color; defaults to ``ProviderTint/gray``.
  init(
    repository: SessionRepository,
    providerLabel: @escaping (String) -> String = { $0 },
    providerTint: @escaping (String) -> ProviderTint = { _ in .gray }
  ) {
    self.repository = repository
    self.providerLabel = providerLabel
    self.providerTint = providerTint
    Task { await refresh() }
  }

  // MARK: - Data lifecycle

  /// Reloads the full session log from the repository.
  func refresh() async {
    let all = try? await repository.sessions(
      over: DateInterval(start: .distantPast, end: .distantFuture))
    sessions = all ?? []
  }

  /// Optimistically adds a just-recorded session to the cache for immediate UI updates.
  ///
  /// Persistence remains the repository's responsibility (via `SessionStore`); this only
  /// keeps the in-memory cache current between reloads.
  /// - Parameter session: The session that was appended.
  func recordAppended(_ session: Session) {
    sessions.append(session)
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

  /// Focus time by task within the current scope, sorted by duration descending.
  var taskBreakdown: [SessionSummary.TaskSlice] { statCards.taskBreakdown }

  /// Focus minutes per day, split by provider, within the current scope.
  var dailyFocusTotals: [DayTotal] {
    let calendar = Calendar.current
    var order: [String] = []
    var accumulated: [String: DayBucket] = [:]

    for session in completedFocus(in: scopedInterval) {
      let day = calendar.startOfDay(for: session.startedAt)
      let providerID = session.taskRef?.providerID ?? Self.untrackedKey
      let key = "\(day.timeIntervalSinceReferenceDate):\(providerID)"
      if accumulated[key] == nil {
        order.append(key)
        accumulated[key] = DayBucket(day: day, providerID: providerID, seconds: 0)
      }
      accumulated[key]!.seconds += session.duration
    }

    return
      order
      .compactMap { key -> DayTotal? in
        guard let entry = accumulated[key] else { return nil }
        return DayTotal(
          day: entry.day, providerID: entry.providerID,
          tint: displayTint(for: entry.providerID), minutes: Int(entry.seconds / 60))
      }
      .sorted { ($0.day, $0.providerID) < ($1.day, $1.providerID) }
  }

  /// Focus time by provider within the current scope, sorted by duration descending.
  var providerBreakdown: [ProviderSlice] {
    var order: [String] = []
    var accumulated: [String: TimeInterval] = [:]

    for session in completedFocus(in: scopedInterval) {
      let providerID = session.taskRef?.providerID ?? Self.untrackedKey
      if accumulated[providerID] == nil { order.append(providerID) }
      accumulated[providerID, default: 0] += session.duration
    }

    return
      order
      .map { providerID in
        ProviderSlice(
          providerID: providerID,
          label: displayLabel(for: providerID),
          tint: displayTint(for: providerID),
          minutes: Int((accumulated[providerID] ?? 0) / 60))
      }
      .sorted { $0.minutes > $1.minutes }
  }

  /// Every task's all-time focus totals, ranked by total minutes descending.
  var allTaskRows: [AllTimeTaskRow] {
    var order: [String] = []
    var accumulated: [String: TaskBucket] = [:]

    for session in sessions where session.phase == .focus && session.wasCompleted {
      let key: String
      if let ref = session.taskRef {
        key = "\(ref.providerID):\(ref.nativeID)"
      } else {
        key = Self.untrackedKey
      }
      if accumulated[key] == nil {
        order.append(key)
        accumulated[key] = TaskBucket(
          taskRef: session.taskRef, title: session.taskTitle ?? "Untracked", seconds: 0,
          last: session.endedAt)
      }
      accumulated[key]!.seconds += session.duration
      if session.endedAt > accumulated[key]!.last { accumulated[key]!.last = session.endedAt }
    }

    return
      order
      .compactMap { key -> AllTimeTaskRow? in
        guard let entry = accumulated[key] else { return nil }
        let resolvedLabel = entry.taskRef.map { providerLabel($0.providerID) } ?? "—"
        return AllTimeTaskRow(
          taskRef: entry.taskRef, title: entry.title, providerLabel: resolvedLabel,
          totalMinutes: Int(entry.seconds / 60), lastSessionDate: entry.last)
      }
      .sorted { $0.totalMinutes > $1.totalMinutes }
  }

  /// Consecutive calendar days ending today (or yesterday, as a grace) with ≥1 focus session.
  var currentStreak: Int {
    let calendar = Calendar.current
    let activeDays = Set(
      sessions
        .filter { $0.phase == .focus && $0.wasCompleted }
        .map { calendar.startOfDay(for: $0.startedAt) })
    guard !activeDays.isEmpty else { return 0 }

    let today = calendar.startOfDay(for: Date())
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

  /// Number of completed focus sessions that started today.
  var todayFocusCount: Int { todaysFocus.count }

  /// Total whole minutes across completed focus sessions that started today.
  var todayFocusMinutes: Int {
    Int(todaysFocus.reduce(0) { $0 + $1.duration } / 60)
  }

  // MARK: - Private

  /// Mutable accumulator for one `(day, provider)` bucket while building `dailyFocusTotals`.
  private struct DayBucket {
    let day: Date
    let providerID: String
    var seconds: TimeInterval
  }

  /// Mutable accumulator for one task while building `allTaskRows`.
  private struct TaskBucket {
    let taskRef: TaskRef?
    let title: String
    var seconds: TimeInterval
    var last: Date
  }

  /// Completed focus sessions that started today (calendar day, local time zone).
  private var todaysFocus: [Session] {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    return sessions.filter {
      $0.phase == .focus && $0.wasCompleted
        && calendar.startOfDay(for: $0.startedAt) == today
    }
  }

  /// Completed focus sessions whose start falls within `interval` (half-open).
  private func completedFocus(in interval: DateInterval) -> [Session] {
    sessions.filter {
      $0.phase == .focus && $0.wasCompleted
        && $0.startedAt >= interval.start && $0.startedAt < interval.end
    }
  }

  /// Display label for a provider grouping key, handling the untracked sentinel.
  private func displayLabel(for providerID: String) -> String {
    providerID == Self.untrackedKey ? "Untracked" : providerLabel(providerID)
  }

  /// Display color for a provider grouping key, gray for the untracked sentinel.
  private func displayTint(for providerID: String) -> ProviderTint {
    providerID == Self.untrackedKey ? .gray : providerTint(providerID)
  }

  /// The date range the scope-dependent outputs are computed over, honoring `offset`.
  private var scopedInterval: DateInterval {
    let calendar = Calendar.current
    let now = Date()
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
          let ref = provider.map { TaskRef(providerID: $0, nativeID: "task-\(slot)") }
          sessions.append(
            Session(
              id: UUID(), phase: .focus, startedAt: start,
              endedAt: start.addingTimeInterval(25 * 60), wasCompleted: true,
              taskRef: ref, taskTitle: provider.map { "\($0.capitalized) task \(slot)" }))
        }
      }
      return seeded(sessions)
    }

    /// Builds a preview view model backed by a temp file seeded with `sessions`.
    private static func seeded(_ sessions: [Session]) -> StatsViewModel {
      let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString + ".json")
      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .iso8601
      if let data = try? encoder.encode(sessions) { try? data.write(to: url) }
      let viewModel = StatsViewModel(
        repository: JSONSessionRepository(fileURL: url),
        providerLabel: { previewProviders[$0]?.label ?? $0 },
        providerTint: { previewProviders[$0]?.tint ?? .gray })
      // Seed the cache synchronously so previews render without waiting on the async refresh.
      viewModel.sessions = sessions
      return viewModel
    }
  }
#endif
