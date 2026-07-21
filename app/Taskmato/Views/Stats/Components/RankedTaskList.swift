//
//  RankedTaskList.swift
//  Taskmato
//

import SwiftUI

/// A ranked list of focus time by task, shown below the daily bar chart.
///
/// Rows come from ``StatsViewModel/taskBreakdown`` (already ordered by duration descending).
struct RankedTaskList: View {

  /// Task focus-time slices, ordered by duration descending.
  let slices: [SessionSummary.TaskSlice]

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("By Task")
        .font(.headline)

      VStack(spacing: 6) {
        ForEach(slices) { slice in
          HStack(spacing: 8) {
            Text(slice.label)
              .lineLimit(1)
            Spacer()
            Text(FocusDuration.label(seconds: slice.seconds))
              .foregroundStyle(.secondary)
              .monospacedDigit()
          }
        }
      }
    }
  }
}
