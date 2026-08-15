//
//  DailyBarChart.swift
//  Taskmato
//

import Charts
import SwiftUI

/// A stacked bar chart of daily focus time, one bar per day, colored by provider.
///
/// Bars come from ``StatsViewModel/dailyFocusTotals`` and the color/legend domain from
/// ``StatsViewModel/providerBreakdown``, so provider colors stay keyed by `providerID`
/// and consistent across the chart and its legend. Plotted in fractional minutes (not
/// floored), so a sub-minute day still draws a real, if tiny, bar — strictly proportional,
/// with no minimum bar height.
struct DailyBarChart: View {

  /// Per-day, per-provider focus seconds driving each stacked segment.
  let totals: [DayTotal]

  /// Providers present in the period, supplying legend labels, colors, and stacking order.
  let providers: [ProviderSlice]

  private var labelByID: [String: String] {
    Dictionary(uniqueKeysWithValues: providers.map { ($0.providerID, $0.label) })
  }

  /// Total focus seconds across every day/provider segment.
  private var totalSeconds: TimeInterval {
    totals.reduce(0) { $0 + $1.seconds }
  }

  /// Provider with the most focus time, when more than one provider is present.
  private var topProvider: ProviderSlice? {
    providers.max { $0.seconds < $1.seconds }
  }

  /// Nonvisual summary of the chart's totals for VoiceOver users.
  private var accessibilitySummary: String {
    guard totalSeconds > 0 else { return "No focus time recorded" }
    let total = FocusDuration.label(seconds: totalSeconds)
    guard let top = topProvider, providers.count > 1 else { return "\(total) total" }
    return "\(total) total. Most on \(top.label): \(FocusDuration.label(seconds: top.seconds))"
  }

  var body: some View {
    VStack(alignment: .leading, spacing: .groupGap) {
      Text("Daily Focus")
        .font(.chartTitle)

      Chart(totals) { total in
        BarMark(
          x: .value("Day", total.day, unit: .day),
          y: .value("Minutes", total.seconds / 60)
        )
        .cornerRadius(.barCornerRadius)
        .foregroundStyle(by: .value("Provider", labelByID[total.providerID] ?? total.providerID))
      }
      .chartForegroundStyleScale(
        domain: providers.map(\.label),
        range: providers.map { Color($0.tint) }
      )
      .chartLegend(position: .bottom, alignment: .leading)
      .chartYAxis {
        AxisMarks { value in
          AxisGridLine()
          AxisValueLabel {
            if let minutes = value.as(Double.self) {
              Text(FocusDuration.label(seconds: minutes * 60))
            }
          }
        }
      }
      .frame(height: 200)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(AppLabels.Accessibility.dailyFocusChart)
      .accessibilityValue(accessibilitySummary)
    }
  }
}
