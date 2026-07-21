//
//  AllTimeTaskTable.swift
//  Taskmato
//

import SwiftUI

/// A sortable table of every task's all-time focus totals.
///
/// Rows come from ``StatsViewModel/allTaskRows``; column sort state is owned by the view
/// (not the view model) so sorting never triggers re-aggregation.
struct AllTimeTaskTable: View {

  /// Every task's all-time focus totals, as produced by the view model.
  let rows: [AllTimeTaskRow]

  @State private var sortOrder = [
    KeyPathComparator(\AllTimeTaskRow.totalMinutes, order: .reverse)
  ]

  var body: some View {
    Table(rows.sorted(using: sortOrder), sortOrder: $sortOrder) {
      TableColumn("Task", value: \.title) { row in
        Text(row.title).lineLimit(1)
      }
      TableColumn("Provider", value: \.providerLabel) { row in
        Text(row.providerLabel).foregroundStyle(.secondary)
      }
      TableColumn("Total", value: \.totalMinutes) { row in
        Text(FocusDuration.label(minutes: row.totalMinutes)).monospacedDigit()
      }
      TableColumn("Last Session", value: \.lastSessionDate) { row in
        Text(row.lastSessionDate.formatted(date: .abbreviated, time: .omitted))
          .foregroundStyle(.secondary)
      }
    }
  }
}
