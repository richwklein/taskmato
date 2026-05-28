//
//  StatsTabView.swift
//  Taskmato
//

import Charts
import SwiftUI

/// The statistics tab shown in the main application window.
///
/// Displays a scope picker (Today / 7 Days), four summary stat cards, and a donut
/// chart of focus time broken down by task. Data is derived from ``SessionStore``.
struct StatsTabView: View {

  var store: SessionStore

  @State private var scope: StatScope = .today
  @Environment(\.openSettings) private var openSettings

  var body: some View {
    VStack(spacing: 0) {
      scopePicker

      if store.sessions.isEmpty {
        ContentUnavailableView(
          "No Sessions Yet",
          systemImage: "chart.bar",
          description: Text("Complete a focus session to see your statistics here.")
        )
      } else {
        let summary = currentSummary
        ScrollView {
          VStack(alignment: .leading, spacing: 20) {
            statGrid(summary)
            if !summary.taskBreakdown.isEmpty {
              taskBreakdownSection(summary)
            }
          }
          .padding()
        }
      }
    }
    .toolbar {
      ToolbarItem(placement: .automatic) {
        Button {
          openSettings()
        } label: {
          Label("Settings", systemImage: "gearshape")
        }
        .help("Open Settings (⌘,)")
      }
    }
  }

  // MARK: - Scope picker

  private var scopePicker: some View {
    Picker("Scope", selection: $scope) {
      ForEach(StatScope.allCases, id: \.self) { statScope in
        Text(statScope.label).tag(statScope)
      }
    }
    .pickerStyle(.segmented)
    .padding([.horizontal, .top])
    .padding(.bottom, 8)
  }

  // MARK: - Stat grid

  private func statGrid(_ summary: SessionSummary) -> some View {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
      StatCardView(icon: "target", value: "\(summary.focusCount)", label: "Sessions")
      StatCardView(
        icon: "timer",
        value: formatDuration(summary.focusSeconds),
        label: "Focus Time"
      )
      StatCardView(icon: "cup.and.saucer", value: "\(summary.breakCount)", label: "Breaks")
      StatCardView(icon: "repeat", value: "\(summary.cycleCount)", label: "Cycles")
    }
  }

  // MARK: - Task breakdown

  private func taskBreakdownSection(_ summary: SessionSummary) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Task Breakdown")
        .font(.headline)

      Chart(summary.taskBreakdown) { slice in
        SectorMark(
          angle: .value("Time", slice.seconds),
          innerRadius: .ratio(0.5),
          angularInset: 1.5
        )
        .cornerRadius(3)
        .foregroundStyle(by: .value("Task", slice.label))
      }
      .chartForegroundStyleScale(
        domain: summary.taskBreakdown.map(\.label),
        range: chartColors(count: summary.taskBreakdown.count)
      )
      .chartLegend(.hidden)
      .frame(height: 160)

      VStack(spacing: 6) {
        ForEach(Array(summary.taskBreakdown.enumerated()), id: \.element.id) { idx, slice in
          HStack(spacing: 8) {
            Circle()
              .fill(sliceColor(idx))
              .frame(width: 10, height: 10)
            Text(slice.label)
              .lineLimit(1)
            Spacer()
            let pct =
              summary.focusSeconds > 0
              ? Int(slice.seconds / summary.focusSeconds * 100) : 0
            Text("\(slice.minutes) min · \(pct)%")
              .foregroundStyle(.secondary)
              .font(.caption)
          }
        }
      }
    }
  }

  // MARK: - Helpers

  private var currentSummary: SessionSummary {
    scope == .today ? store.todaySummary() : store.thisWeekSummary()
  }

  private static let palette: [Color] = [
    .blue, .green, .orange, .purple, .red, .teal, .indigo, .pink,
  ]

  private func sliceColor(_ index: Int) -> Color {
    Self.palette[index % Self.palette.count]
  }

  private func chartColors(count: Int) -> [Color] {
    (0..<count).map { sliceColor($0) }
  }

  /// Formats a duration in seconds as `"Xh Ym"` when ≥ 60 min, otherwise `"Xm"`.
  private func formatDuration(_ seconds: TimeInterval) -> String {
    let minutes = Int(seconds / 60)
    if minutes >= 60 {
      let hours = minutes / 60
      let mins = minutes % 60
      return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
    }
    return "\(minutes)m"
  }
}

// MARK: - Scope

private enum StatScope: CaseIterable {
  case today
  case thisWeek

  var label: String {
    switch self {
    case .today: return "Today"
    case .thisWeek: return "7 Days"
    }
  }
}

// MARK: - StatCardView

/// A compact summary card showing a single metric with an icon, value, and label.
private struct StatCardView: View {

  let icon: String
  let value: String
  let label: String

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Image(systemName: icon)
        .font(.title2)
        .foregroundStyle(.secondary)
      Text(value)
        .font(.title)
        .fontWeight(.semibold)
        .monospacedDigit()
      Text(label)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(.background.secondary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

#Preview {
  StatsTabView(store: SessionStore())
}
