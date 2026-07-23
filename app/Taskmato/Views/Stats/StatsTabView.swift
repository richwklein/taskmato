//
//  StatsTabView.swift
//  Taskmato
//

import SwiftUI

/// The statistics tab shown in the main application window.
///
/// Shows a scope picker and, for every scope except All Time, period back/forward navigation.
/// Each scope renders its own visualisation — a task donut (Today), a stacked daily bar chart
/// with a ranked task list (7 Days / This Month), or a sortable all-time task table. All data
/// is derived from ``StatsViewModel``.
struct StatsTabView: View {

  @Bindable var statsViewModel: StatsViewModel

  var body: some View {
    VStack(spacing: 0) {
      scopePicker
      navigationRow
      content
    }
  }

  // MARK: - Content

  @ViewBuilder
  private var content: some View {
    if statsViewModel.isEmpty {
      emptyState(
        "No Sessions Yet",
        description: "Complete a focus session to see your statistics here.")
    } else {
      let summary = statsViewModel.statCards
      if summary.focusCount == 0 && summary.breakCount == 0 {
        emptyState(
          "No Sessions",
          description: "No focus sessions in this period.")
      } else {
        scopeContent(summary)
      }
    }
  }

  @ViewBuilder
  private func scopeContent(_ summary: SessionSummary) -> some View {
    switch statsViewModel.scope {
    case .allTime:
      VStack(alignment: .leading, spacing: .sectionGap) {
        statGrid(summary).padding([.horizontal, .top])
        AllTimeTaskTable(rows: statsViewModel.allTaskRows)
      }
    default:
      ScrollView {
        VStack(alignment: .leading, spacing: .sectionGap) {
          statGrid(summary)
          scopeCharts(summary)
        }
        .padding()
      }
    }
  }

  @ViewBuilder
  private func scopeCharts(_ summary: SessionSummary) -> some View {
    switch statsViewModel.scope {
    case .today:
      if !summary.taskBreakdown.isEmpty {
        TaskDonutChart(slices: summary.taskBreakdown, totalSeconds: summary.focusSeconds)
      }
    case .thisWeek, .thisMonth:
      DailyBarChart(
        totals: statsViewModel.dailyFocusTotals,
        providers: statsViewModel.providerBreakdown)
      if !summary.taskBreakdown.isEmpty {
        RankedTaskList(slices: summary.taskBreakdown)
      }
    case .allTime:
      EmptyView()
    }
  }

  // MARK: - Scope picker

  private var scopePicker: some View {
    Picker("Scope", selection: $statsViewModel.scope) {
      ForEach(StatScope.allCases, id: \.self) { statScope in
        Text(statScope.label).tag(statScope)
      }
    }
    .pickerStyle(.segmented)
    .labelsHidden()
    .padding([.horizontal, .top])
    .padding(.bottom, .sectionGap)
  }

  // MARK: - Period navigation

  /// Always rendered so its height is constant across scopes; the arrows are hidden for All
  /// Time (which has no period navigation) to keep the layout from jumping.
  private var navigationRow: some View {
    let showsArrows = statsViewModel.canNavigateBack
    return HStack(spacing: .contentGap) {
      Button {
        statsViewModel.navigateBack()
      } label: {
        Image(systemName: "chevron.left")
      }
      .disabled(!showsArrows)
      .opacity(showsArrows ? 1 : 0)
      .accessibilityLabel("Previous period")

      Text(periodLabel)
        .font(.sectionHeader)
        .monospacedDigit()
        .frame(width: 160)

      Button {
        statsViewModel.navigateForward()
      } label: {
        Image(systemName: "chevron.right")
      }
      .disabled(!statsViewModel.canNavigateForward)
      .opacity(showsArrows ? 1 : 0)
      .accessibilityLabel("Next period")
    }
    .buttonStyle(.borderless)
    .frame(maxWidth: .infinity)
    .padding(.horizontal)
    .padding(.bottom, .contentGap)
  }

  /// The navigated period rendered for the current scope and offset.
  private var periodLabel: String {
    let interval = statsViewModel.currentInterval
    switch statsViewModel.scope {
    case .today:
      switch statsViewModel.offset {
      case 0: return "Today"
      case -1: return "Yesterday"
      default: return interval.start.formatted(.dateTime.month(.abbreviated).day())
      }
    case .thisWeek:
      let lastDay = interval.end.addingTimeInterval(-1)
      let start = interval.start.formatted(.dateTime.month(.abbreviated).day())
      let end = lastDay.formatted(.dateTime.month(.abbreviated).day())
      return "\(start) – \(end)"
    case .thisMonth:
      return interval.start.formatted(.dateTime.month(.wide).year())
    case .allTime:
      return "All Time"
    }
  }

  // MARK: - Stat grid

  private func statGrid(_ summary: SessionSummary) -> some View {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: .groupGap) {
      StatCardView(icon: "target", value: "\(summary.focusCount)", label: "Sessions")
      StatCardView(
        icon: "timer",
        value: FocusDuration.label(seconds: summary.focusSeconds),
        label: "Focus Time"
      )
      StatCardView(icon: "cup.and.saucer", value: "\(summary.breakCount)", label: "Breaks")
      StatCardView(icon: "repeat", value: "\(summary.cycleCount)", label: "Cycles")
    }
  }

  // MARK: - Empty state

  private func emptyState(_ title: String, description: String) -> some View {
    ContentUnavailableView(
      title,
      systemImage: "chart.bar",
      description: Text(description)
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

#Preview("Today") {
  StatsTabView(statsViewModel: .previewSeeded)
    .frame(width: 420, height: 560)
}

#Preview("7 Days") {
  let viewModel = StatsViewModel.previewSeeded
  viewModel.scope = .thisWeek
  return StatsTabView(statsViewModel: viewModel)
    .frame(width: 420, height: 560)
}

#Preview("All Time") {
  let viewModel = StatsViewModel.previewSeeded
  viewModel.scope = .allTime
  return StatsTabView(statsViewModel: viewModel)
    .frame(width: 420, height: 560)
}

#Preview("Empty") {
  StatsTabView(statsViewModel: .preview)
    .frame(width: 420, height: 560)
}
