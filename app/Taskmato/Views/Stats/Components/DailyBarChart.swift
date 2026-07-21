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

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Daily Focus")
        .font(.headline)

      Chart(totals) { total in
        BarMark(
          x: .value("Day", total.day, unit: .day),
          y: .value("Minutes", total.minutes)
        )
        .cornerRadius(2)
        .foregroundStyle(by: .value("Provider", labelByID[total.providerID] ?? total.providerID))
      }
      .chartForegroundStyleScale(
        domain: providers.map(\.label),
        range: providers.map { Color($0.tint) }
      )
      .chartLegend(position: .bottom, alignment: .leading)
      .frame(height: 200)
    }
  }
}
