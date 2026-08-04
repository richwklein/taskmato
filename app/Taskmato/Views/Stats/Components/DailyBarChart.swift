//
//  DailyBarChart.swift
//  Taskmato
//

import Charts
import SwiftUI

/// A stacked bar chart of daily focus minutes, one bar per day, colored by provider.
///
/// Bars come from ``StatsViewModel/dailyFocusTotals`` and the color/legend domain from
/// ``StatsViewModel/providerBreakdown``, so provider colors stay keyed by `providerID`
/// and consistent across the chart and its legend.
struct DailyBarChart: View {

  /// Per-day, per-provider focus minutes driving each stacked segment.
  let totals: [DayTotal]

  /// Providers present in the period, supplying legend labels, colors, and stacking order.
  let providers: [ProviderSlice]

  private var labelByID: [String: String] {
    Dictionary(uniqueKeysWithValues: providers.map { ($0.providerID, $0.label) })
  }

  /// Total focus minutes across every day/provider segment.
  private var totalMinutes: Int {
    totals.reduce(0) { $0 + $1.minutes }
  }

  /// Provider with the most focus minutes, when more than one provider is present.
  private var topProvider: ProviderSlice? {
    providers.max { $0.minutes < $1.minutes }
  }

  /// Nonvisual summary of the chart's totals for VoiceOver users.
  private var accessibilitySummary: String {
    guard totalMinutes > 0 else { return "No focus time recorded" }
    let total = FocusDuration.label(minutes: totalMinutes)
    guard let top = topProvider, providers.count > 1 else { return "\(total) total" }
    return "\(total) total. Most on \(top.label): \(FocusDuration.label(minutes: top.minutes))"
  }

  var body: some View {
    VStack(alignment: .leading, spacing: .groupGap) {
      Text("Daily Focus")
        .font(.chartTitle)

      Chart(totals) { total in
        BarMark(
          x: .value("Day", total.day, unit: .day),
          y: .value("Minutes", total.minutes)
        )
        .cornerRadius(.barCornerRadius)
        .foregroundStyle(by: .value("Provider", labelByID[total.providerID] ?? total.providerID))
      }
      .chartForegroundStyleScale(
        domain: providers.map(\.label),
        range: providers.map { Color($0.tint) }
      )
      .chartLegend(position: .bottom, alignment: .leading)
      .frame(height: 200)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(AppLabels.Accessibility.dailyFocusChart)
      .accessibilityValue(accessibilitySummary)
    }
  }
}
