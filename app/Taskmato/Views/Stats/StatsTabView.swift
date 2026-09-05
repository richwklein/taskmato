//
//  StatsTabView.swift
//  Taskmato
//

import SwiftUI

/// The statistics tab shown in the main application window.
///
/// The scope is chosen from the sidebar's Stats section (which sets ``StatsViewModel/scope``);
/// for every scope except All Time this view shows period back/forward navigation. Every scope
/// shares the same shell — stat cards, then the scope's own chart (a task donut for Today, a
/// stacked daily bar chart for 7 Days / This Month, the weekly chart for All Time), then the
/// same ``StatsTaskTable``. All data is derived from ``StatsViewModel``.
struct StatsTabView: View {

  @Bindable var statsViewModel: StatsViewModel

  /// Persists the one-time dismissal of the session-history footer.
  var settings: AppSettings

  @State private var weeklyChartViewportState = WeeklyChartViewportState()

  var body: some View {
    VStack(spacing: 0) {
      navigationRow
      content
      if !settings.statsHistoryFooterDismissed { historyFooter }
    }
    .onAppear { statsViewModel.refreshTemporalContext() }
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
      if summary.focusCount == 0 && summary.breakCount == 0 && summary.focusSeconds == 0 {
        emptyState(
          "No Sessions",
          description: "No focus sessions in this period.")
      } else {
        scopeContent(summary)
      }
    }
  }

  /// One scroll region for every scope: stat cards, the scope's chart, then the task table.
  ///
  /// The table lays out at its intrinsic height inside this scroll view rather than scrolling
  /// itself, so the page never nests a second scroller.
  private func scopeContent(_ summary: SessionSummary) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: .sectionGap) {
        statGrid(summary)
        scopeChart(summary)
        let rows = statsViewModel.taskRows
        if !rows.isEmpty { StatsTaskTable(rows: rows) }
      }
      .padding()
    }
  }

  @ViewBuilder
  private func scopeChart(_ summary: SessionSummary) -> some View {
    switch statsViewModel.scope {
    case .today:
      if !summary.taskBreakdown.isEmpty {
        TaskDonutChart(slices: summary.taskBreakdown, totalSeconds: summary.focusSeconds)
      }
    case .thisWeek, .thisMonth:
      DailyBarChart(
        totals: statsViewModel.dailyFocusTotals,
        providers: statsViewModel.providerBreakdown)
    case .allTime:
      WeeklyBarChart(
        totals: statsViewModel.weeklyFocusTotals,
        providers: statsViewModel.weeklyFocusProviders,
        calendar: statsViewModel.currentCalendar,
        now: statsViewModel.currentDate,
        viewportState: $weeklyChartViewportState)
    }
  }

  // MARK: - History footer

  /// A one-time pointer to session import/export, dismissed permanently by the close button.
  ///
  /// The capability itself stays in Settings, so dismissing only retires the nudge.
  private var historyFooter: some View {
    HStack(spacing: .contentGap) {
      SettingsLink {
        Text("Import or export session history in Settings…")
          .multilineTextAlignment(.center)
      }
      .buttonStyle(.link)

      Button {
        settings.statsHistoryFooterDismissed = true
      } label: {
        Image(systemName: "xmark")
          .imageScale(.small)
      }
      .buttonStyle(.borderless)
      .foregroundStyle(.secondary)
      .help("Dismiss")
      .accessibilityLabel("Dismiss")
    }
    .frame(maxWidth: .infinity)
    .padding(.horizontal)
    .padding(.vertical, .contentGap)
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
    .padding([.horizontal, .top])
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
        label: "Focus Time",
        help: AppLabels.Tooltip.focusTimeIncludesEarlyStops
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

#if DEBUG
  #Preview("Today") {
    StatsTabView(statsViewModel: .previewSeeded, settings: AppSettings())
      .frame(width: 420, height: 560)
  }

  #Preview("7 Days") {
    let viewModel = StatsViewModel.previewSeeded
    viewModel.scope = .thisWeek
    return StatsTabView(statsViewModel: viewModel, settings: AppSettings())
      .frame(width: 420, height: 560)
  }

  #Preview("All Time") {
    let viewModel = StatsViewModel.previewSeeded
    viewModel.scope = .allTime
    return StatsTabView(statsViewModel: viewModel, settings: AppSettings())
      .frame(width: 420, height: 560)
  }

  #Preview("Empty") {
    StatsTabView(statsViewModel: .preview, settings: AppSettings())
      .frame(width: 420, height: 560)
  }
#endif
