//
//  StatTypes.swift
//  Taskmato
//

import Foundation

/// The time window a stats view is scoped to.
enum StatScope: CaseIterable {

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

  /// Focus minutes attributed to this provider on this day.
  let minutes: Int

  /// Stable identity combining the day and provider.
  var id: String { "\(day.timeIntervalSinceReferenceDate):\(providerID)" }
}

/// A provider's aggregate share of focus time within the current scope/period.
struct ProviderSlice: Identifiable {

  /// Provider that owns the focus time, or `"__untracked__"` when no task was selected.
  let providerID: String

  /// Human-readable provider name shown in the legend.
  let label: String

  /// Semantic color of the provider, used for the legend swatch and bar segments.
  let tint: ProviderTint

  /// Focus minutes attributed to this provider.
  let minutes: Int

  /// Stable identity derived from the provider.
  var id: String { providerID }
}

/// A row in the All Time sortable task table.
struct AllTimeTaskRow: Identifiable {

  /// The task this row aggregates, or `nil` for untracked focus time.
  let taskRef: TaskRef?

  /// `Session.taskTitle` snapshot; `"Untracked"` when no task was selected.
  let title: String

  /// Human-readable provider name, or `"—"` for untracked focus time.
  let providerLabel: String

  /// Total focus minutes across every session attributed to this task.
  let totalMinutes: Int

  /// When the most recent session for this task ended.
  let lastSessionDate: Date

  /// Stable identity derived from the task reference, falling back to the title.
  var id: String {
    if let taskRef { return "\(taskRef.providerID):\(taskRef.nativeID)" }
    return "__untracked__"
  }
}
