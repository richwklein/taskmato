//
//  TaskDonutChart.swift
//  Taskmato
//

import Charts
import SwiftUI

/// A donut chart of focus time by task, with a color-keyed legend below.
///
/// Slices are colored by task (not provider); the Today scope uses this to break the
/// day's focus time down across the tasks worked on.
struct TaskDonutChart: View {

  /// Focus-time slices, one per task, ordered by duration descending.
  let slices: [SessionSummary.TaskSlice]

  /// Total focus seconds in the period, used to compute each slice's percentage.
  let totalSeconds: TimeInterval

  private func color(_ index: Int) -> Color {
    Color.chartPalette[index % Color.chartPalette.count]
  }

  /// Slice with the most focus seconds, when at least one slice is present.
  private var topSlice: SessionSummary.TaskSlice? {
    slices.max { $0.seconds < $1.seconds }
  }

  /// Nonvisual summary of the chart's totals for VoiceOver users.
  private var accessibilitySummary: String {
    guard totalSeconds > 0, let top = topSlice else { return "No focus time recorded" }
    let total = FocusDuration.label(seconds: totalSeconds)
    let taskCount = slices.count == 1 ? "1 task" : "\(slices.count) tasks"
    let topPercent = Int(top.seconds / totalSeconds * 100)
    return "\(total) total across \(taskCount). Most on \(top.label): \(topPercent)%"
  }

  var body: some View {
    VStack(alignment: .leading, spacing: .groupGap) {
      Text("Task Breakdown")
        .font(.chartTitle)

      Chart(slices) { slice in
        SectorMark(
          angle: .value("Time", slice.seconds),
          innerRadius: .ratio(0.5),
          angularInset: 1.5
        )
        .cornerRadius(.barCornerRadius)
        .foregroundStyle(by: .value("Task", slice.label))
      }
      .chartForegroundStyleScale(
        domain: slices.map(\.label),
        range: (0..<slices.count).map(color)
      )
      .chartLegend(.hidden)
      .frame(height: 160)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(AppLabels.Accessibility.taskBreakdownChart)
      .accessibilityValue(accessibilitySummary)

      VStack(spacing: .iconLabel) {
        ForEach(Array(slices.enumerated()), id: \.element.id) { index, slice in
          HStack(spacing: .contentGap) {
            Circle()
              .fill(color(index))
              .frame(width: 10, height: 10)
            Text(ContentFormat.markdown.attributedString(for: slice.label))
              .lineLimit(1)
            Spacer()
            let pct = totalSeconds > 0 ? Int((slice.seconds / totalSeconds * 100).rounded()) : 0
            Text("\(FocusDuration.label(seconds: slice.seconds)) · \(pct)%")
              .foregroundStyle(.secondary)
              .font(.caption)
          }
        }
      }
    }
  }
}
