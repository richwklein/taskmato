//
//  StatTypes.swift
//  Taskmato
//

import Foundation

/// The time window a stats view is scoped to.
///
/// `String`-backed so the persisted shell destination (design doc 0008, D9) has a stable
/// on-disk representation independent of case ordering.
enum StatScope: String, CaseIterable, Codable {

  /// The current calendar day.
  case today

  /// A rolling seven-day window.
  case thisWeek

  /// The current calendar month.
  case thisMonth

  /// Every recorded session, ignoring period navigation.
  case allTime

  /// Human-readable title shown in the scope picker.
  ///
  /// Generalized to the period *kind* (Day, Week, Month) so it reads correctly alongside the
  /// navigation label, which names the specific period being viewed.
  var label: String {
    switch self {
    case .today: return "Day"
    case .thisWeek: return "Week"
    case .thisMonth: return "Month"
    case .allTime: return "All Time"
    }
  }

  /// Human-readable title shown as a sidebar scope row.
  ///
  /// Names the specific period (unlike ``label``, which names the period *kind* for the
  /// segmented picker), since the sidebar row is the whole selection affordance.
  var sidebarLabel: String {
    switch self {
    case .today: return "Today"
    case .thisWeek: return "7 Days"
    case .thisMonth: return "This Month"
    case .allTime: return "All Time"
    }
  }
}

/// One day's focus contribution from a single provider, used in the stacked bar chart.
struct DayTotal: Identifiable {

  /// Start of day in the local time zone; the bar's x-axis position.
  let day: Date

  /// Provider that owns the focus time, or `"__untracked__"` when no task was selected.
  let providerID: String

  /// Semantic color of the owning provider, used for the stacked bar segment.
  let tint: ProviderTint

  /// Focus seconds attributed to this provider on this day.
  let seconds: TimeInterval

  /// Stable identity combining the day and provider.
  var id: String { "\(day.timeIntervalSinceReferenceDate):\(providerID)" }
}

/// One calendar week's focus contribution from a single provider, used in the all-time chart.
struct WeekTotal: Identifiable {

  /// Start of the calendar week in the user's current calendar and time zone.
  let week: Date

  /// Provider that owns the focus time, or `"__untracked__"` when no task was selected.
  let providerID: String

  /// Semantic color of the owning provider, used for the stacked segment.
  let tint: ProviderTint

  /// Focus seconds attributed to this provider in this week.
  let seconds: TimeInterval

  /// Stable identity combining the week and provider.
  var id: String { "\(week.timeIntervalSinceReferenceDate):\(providerID)" }
}

/// A provider's aggregate share of focus time within the current scope/period.
struct ProviderSlice: Identifiable {

  /// Provider that owns the focus time, or `"__untracked__"` when no task was selected.
  let providerID: String

  /// Human-readable provider name shown in the legend.
  let label: String

  /// Semantic color of the provider, used for the legend swatch and bar segments.
  let tint: ProviderTint

  /// Focus seconds attributed to this provider.
  let seconds: TimeInterval

  /// Stable identity derived from the provider.
  var id: String { providerID }
}

/// A row in the sortable task table shown beneath every scope's chart.
nonisolated struct StatsTaskRow: Identifiable, Sendable {

  /// The task this row aggregates, or `nil` for untracked focus time.
  let taskRef: TaskRef?

  /// `FocusSegment.taskTitle` snapshot; `"Untracked"` when no task was selected.
  let title: String

  /// Human-readable provider name, or `"—"` for untracked focus time.
  let providerLabel: String

  /// Total focus seconds attributed to this task within the current scope.
  let totalSeconds: TimeInterval

  /// When the task's most recent session within the current scope ended.
  let lastSessionDate: Date

  /// Stable identity derived from the task reference, falling back to the title.
  var id: String {
    if let taskRef { return "\(taskRef.providerID):\(taskRef.nativeID)" }
    return "__untracked__"
  }
}
