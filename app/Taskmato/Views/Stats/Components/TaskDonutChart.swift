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

  /// Ordered palette assigned to slices by index.
  private static let palette: [Color] = [
    .blue, .green, .orange, .purple, .red, .teal, .indigo, .pink,
  ]

  private func color(_ index: Int) -> Color {
    Self.palette[index % Self.palette.count]
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Task Breakdown")
        .font(.headline)

      Chart(slices) { slice in
        SectorMark(
          angle: .value("Time", slice.seconds),
          innerRadius: .ratio(0.5),
          angularInset: 1.5
        )
        .cornerRadius(3)
        .foregroundStyle(by: .value("Task", slice.label))
      }
      .chartForegroundStyleScale(
        domain: slices.map(\.label),
        range: (0..<slices.count).map(color)
      )
      .chartLegend(.hidden)
      .frame(height: 160)

      VStack(spacing: 6) {
        ForEach(Array(slices.enumerated()), id: \.element.id) { index, slice in
          HStack(spacing: 8) {
            Circle()
              .fill(color(index))
              .frame(width: 10, height: 10)
            Text(slice.label)
              .lineLimit(1)
            Spacer()
            let pct = totalSeconds > 0 ? Int(slice.seconds / totalSeconds * 100) : 0
            Text("\(slice.minutes) min · \(pct)%")
              .foregroundStyle(.secondary)
              .font(.caption)
          }
        }
      }
    }
  }
}
