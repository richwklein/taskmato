//
//  WeeklyBarChart.swift
//  Taskmato
//

import Charts
import SwiftUI

/// A provider-stacked, scrollable chart of all recorded focus time by calendar week.
struct WeeklyBarChart: View {
  /// Per-week, per-provider focus totals driving stacked segments.
  let totals: [WeekTotal]
  /// Provider labels, tints, and deterministic stacking order.
  let providers: [ProviderSlice]
  /// Calendar used for all week arithmetic and date presentation.
  let calendar: Calendar
  /// Snapshot used to anchor the initial viewport.
  let now: Date
  /// Externally-owned chart coordinate and reconciliation context.
  @Binding var viewportState: WeeklyChartViewportState

  private var positiveTotals: [WeekTotal] { totals.filter { $0.seconds > 0 } }
  private var viewport: WeeklyChartViewport? {
    guard let earliest = positiveTotals.map(\.week).min(),
      let latest = positiveTotals.map(\.week).max()
    else { return nil }
    return WeeklyChartViewport(
      earliestPositiveWeek: earliest, lastRecordedWeek: latest, now: now, calendar: calendar)
  }
  private var signature: WeeklyChartSignature {
    WeeklyChartSignature(
      earliest: positiveTotals.map(\.week).min(), latest: positiveTotals.map(\.week).max(),
      current: WeeklyChartViewport.weekStart(now, calendar: calendar), calendar: calendar)
  }
  private var orderedProviders: [ProviderSlice] {
    let positiveIDs = Set(positiveTotals.map(\.providerID))
    return providers.filter { positiveIDs.contains($0.providerID) }.sorted {
      $0.providerID < $1.providerID
    }
  }
  private var providerNames: [String: String] {
    let duplicateLabels = Set(
      Dictionary(grouping: orderedProviders, by: \.label).compactMap {
        $0.value.count > 1 ? $0.key : nil
      })
    return Dictionary(
      uniqueKeysWithValues: orderedProviders.map {
        (
          $0.providerID,
          duplicateLabels.contains($0.label) ? "\($0.label) (\($0.providerID))" : $0.label
        )
      })
  }
  private var yMaximum: Double {
    let stacks = Dictionary(grouping: positiveTotals, by: \.week).values.map {
      $0.reduce(0) { $0 + $1.seconds }
    }
    return max(60, stacks.max() ?? 0) / 60
  }

  var body: some View {
    VStack(alignment: .leading, spacing: .groupGap) {
      Text("Weekly Focus").font(.chartTitle)
      if let viewport {
        chart(viewport)
        controls(viewport)
        legend
      } else {
        Text("No focus time recorded").foregroundStyle(.secondary)
      }
    }
    .onAppear { reconcileViewport() }
    .onChange(of: signature) { _, _ in reconcileViewport() }
  }

  @ViewBuilder private func chart(_ viewport: WeeklyChartViewport) -> some View {
    Chart {
      ForEach(chartSegments(in: viewport)) { weeklyMark($0) }
    }
    .chartXScale(domain: 0...Double(viewport.weekCount))
    .chartScrollableAxes(.horizontal)
    .chartXVisibleDomain(length: Double(viewport.visibleWidth))
    .chartScrollPosition(x: $viewportState.scrollStart)
    .chartScrollTargetBehavior(.valueAligned(unit: 1))
    .chartYScale(domain: 0...yMaximum)
    .chartLegend(.hidden)
    .chartForegroundStyleScale(
      domain: orderedProviders.map(\.providerID), range: orderedProviders.map { Color($0.tint) }
    )
    .chartXAxis {
      AxisMarks(values: monthTicks(in: viewport).map(\.position)) { value in
        AxisGridLine()
        AxisValueLabel(collisionResolution: .greedy) {
          if let position = value.as(Double.self) {
            if let tick = monthTick(at: position, in: viewport) {
              Text(tick.label)
            }
          }
        }
      }
    }
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
    .frame(height: 220)
    .accessibilityLabel("Weekly focus chart")
  }

  @ViewBuilder private func controls(_ viewport: WeeklyChartViewport) -> some View {
    ViewThatFits(in: .horizontal) {
      controlRow(viewport, compact: false)
      controlRow(viewport, compact: true)
    }.buttonStyle(.borderless)
  }
  private func controlRow(_ viewport: WeeklyChartViewport, compact: Bool) -> some View {
    HStack {
      Button {
        moveViewport(by: -WeeklyChartViewport.pageLength)
      } label: {
        navigationLabel("Previous 26 weeks", image: "chevron.left", compact: compact)
      }
      .help("Previous 26 weeks").accessibilityLabel("Previous 26 weeks").disabled(
        !viewport.canMoveBackward(from: viewportState.scrollStart))
      Spacer()
      Text(dateRangeLabel(for: viewport)).font(.caption).foregroundStyle(.secondary)
        .monospacedDigit()
      Spacer()
      Button {
        moveViewport(by: WeeklyChartViewport.pageLength)
      } label: {
        navigationLabel("Next 26 weeks", image: "chevron.right", compact: compact)
      }
      .help("Next 26 weeks").accessibilityLabel("Next 26 weeks").disabled(
        !viewport.canMoveForward(from: viewportState.scrollStart))
    }
  }

  @ViewBuilder
  private func navigationLabel(
    _ title: String, image: String, compact: Bool
  ) -> some View {
    if compact {
      Label(title, systemImage: image).labelStyle(.iconOnly)
    } else {
      Label(title, systemImage: image)
    }
  }

  private var legend: some View {
    FlowLayout(spacing: 8) {
      ForEach(orderedProviders) { provider in
        HStack(spacing: 4) {
          Circle().fill(Color(provider.tint)).frame(width: 8, height: 8)
          Text(providerNames[provider.providerID] ?? provider.label)
        }.font(.caption)
      }
    }
  }
  private func reconcileViewport() {
    viewportState.reconcile(viewport, now: now, calendar: calendar)
  }
  private func moveViewport(by weeks: Int) {
    if let viewport {
      viewportState.scrollStart = viewport.movedScrollStart(viewportState.scrollStart, by: weeks)
    }
  }
  private func dateRangeLabel(for viewport: WeeklyChartViewport) -> String {
    let weeks = viewport.visibleWeeks(at: viewportState.scrollStart, calendar: calendar)
    guard let first = weeks.first, let last = weeks.last else { return "" }
    return "\(dateLabel(first)) – \(dateLabel(weekEnd(last)))"
  }
  private func weekEnd(_ week: Date) -> Date {
    calendar.date(byAdding: .day, value: 6, to: week) ?? week
  }
  private func dateLabel(_ date: Date) -> String {
    date.formatted(
      Date.FormatStyle(calendar: calendar, timeZone: calendar.timeZone).month(.abbreviated).day()
        .year())
  }
  private func monthTicks(in viewport: WeeklyChartViewport) -> [MonthTick] {
    viewport.monthBoundaryDates(calendar: calendar).map {
      MonthTick(
        date: $0, position: viewport.monthPosition(for: $0, calendar: calendar),
        label: $0.formatted(
          Date.FormatStyle(calendar: calendar, timeZone: calendar.timeZone).month(.abbreviated)
            .year()))
    }
  }
  private func monthTick(at position: Double, in viewport: WeeklyChartViewport) -> MonthTick? {
    monthTicks(in: viewport).min { abs($0.position - position) < abs($1.position - position) }
  }
  private func chartSegments(in viewport: WeeklyChartViewport) -> [WeeklyStackSegment] {
    let grouped = Dictionary(
      grouping: positiveTotals, by: { WeeklyChartViewport.weekStart($0.week, calendar: calendar) })
    return grouped.keys.sorted().flatMap { week in
      var running: TimeInterval = 0
      let totals = Dictionary(
        uniqueKeysWithValues: (grouped[week] ?? []).map { ($0.providerID, $0) })
      return orderedProviders.compactMap { provider -> WeeklyStackSegment? in
        guard let total = totals[provider.providerID] else { return nil }
        defer { running += total.seconds }
        return WeeklyStackSegment(
          total: total, start: running, end: running + total.seconds,
          weekOffset: Double(viewport.offset(for: week, calendar: calendar)))
      }
    }
  }
  @ChartContentBuilder private func weeklyMark(_ segment: WeeklyStackSegment) -> some ChartContent {
    RectangleMark(
      xStart: .value("Week start", segment.weekOffset + 0.1),
      xEnd: .value("Week end", segment.weekOffset + 0.9),
      yStart: .value("Stack start", segment.start / 60),
      yEnd: .value("Focus time", segment.end / 60)
    )
    .foregroundStyle(by: .value("Provider", segment.total.providerID))
    .accessibilityLabel("\(dateLabel(segment.total.week)), \(detailLabel(for: segment.total))")
    .accessibilityValue(FocusDuration.label(seconds: segment.total.seconds))
  }
  private func detailLabel(for total: WeekTotal) -> String {
    "\(providerNames[total.providerID] ?? total.providerID): \(FocusDuration.label(seconds: total.seconds))"
  }
}

/// Inputs that change the calendar coordinate domain.
private struct WeeklyChartSignature: Equatable {
  let earliest: Date?
  let latest: Date?
  let current: Date
  let calendar: Calendar
}
/// One provider segment positioned within a stacked weekly bar.
private struct WeeklyStackSegment: Identifiable {
  let total: WeekTotal
  let start: TimeInterval
  let end: TimeInterval
  let weekOffset: Double
  var id: String { total.id }
}
/// A month boundary positioned by its actual elapsed fraction of the containing week.
private struct MonthTick: Identifiable {
  let date: Date
  let position: Double
  let label: String
  var id: Date { date }
}
/// A compact wrapping layout for the provider legend.
private struct FlowLayout: Layout {
  let spacing: CGFloat
  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let maxWidth = proposal.width ?? .greatestFiniteMagnitude
    var width: CGFloat = 0
    var height: CGFloat = 0
    var rowHeight: CGFloat = 0
    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)
      if width + size.width > maxWidth, width > 0 {
        height += rowHeight + spacing
        width = 0
        rowHeight = 0
      }
      width += size.width + (width == 0 ? 0 : spacing)
      rowHeight = max(rowHeight, size.height)
    }
    return CGSize(width: min(width, maxWidth), height: height + rowHeight)
  }
  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) {
    var point = bounds.origin
    var rowHeight: CGFloat = 0
    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)
      if point.x + size.width > bounds.maxX, point.x > bounds.minX {
        point.x = bounds.minX
        point.y += rowHeight + spacing
        rowHeight = 0
      }
      subview.place(at: point, proposal: ProposedViewSize(size))
      point.x += size.width + spacing
      rowHeight = max(rowHeight, size.height)
    }
  }
}
