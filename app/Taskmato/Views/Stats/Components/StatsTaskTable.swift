//
//  StatsTaskTable.swift
//  Taskmato
//

import SwiftUI

/// A sortable, non-scrolling table of per-task focus totals, shared by every stats scope.
///
/// Rows come from ``StatsViewModel/taskRows``, which scopes them to the selected period; the
/// columns are identical in every scope so the layout never shifts as the scope changes. Sort
/// state is owned by the view (not the view model) so sorting never triggers re-aggregation.
///
/// Laid out with `Grid` rather than `Table` deliberately: `Table` wraps an `NSScrollView` and
/// never sizes to its content, which would nest a second scroller inside the stats page.
struct StatsTaskTable: View {

  /// Per-task focus totals for the current scope.
  let rows: [StatsTaskRow]

  @State private var sort = SortOrder(column: .total, isAscending: false)

  var body: some View {
    VStack(alignment: .leading, spacing: .groupGap) {
      Text("By Task").font(.chartTitle)

      Grid(alignment: .leading, horizontalSpacing: .groupGap, verticalSpacing: .rowVertical) {
        GridRow {
          header("Task", .title)
          header("Provider", .provider)
          header("Total", .total).gridColumnAlignment(.trailing)
          header("Last Session", .lastSession).gridColumnAlignment(.trailing)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)

        Divider().gridCellColumns(4)

        ForEach(sortedRows) { row in
          GridRow {
            Text(ContentFormat.markdown.attributedString(for: row.title)).lineLimit(1)
            Text(row.providerLabel).foregroundStyle(.secondary).lineLimit(1)
            Text(FocusDuration.label(seconds: row.totalSeconds)).monospacedDigit()
            Text(row.lastSessionDate.formatted(date: .abbreviated, time: .omitted))
              .foregroundStyle(.secondary).monospacedDigit()
          }
        }
      }
      .font(.callout)
    }
  }

  private var sortedRows: [StatsTaskRow] {
    rows.sorted { lhs, rhs in
      let ascending = sort.isAscending
      switch sort.column {
      case .title: return ascending ? lhs.title < rhs.title : lhs.title > rhs.title
      case .provider:
        return ascending
          ? lhs.providerLabel < rhs.providerLabel : lhs.providerLabel > rhs.providerLabel
      case .total:
        return ascending ? lhs.totalSeconds < rhs.totalSeconds : lhs.totalSeconds > rhs.totalSeconds
      case .lastSession:
        return ascending
          ? lhs.lastSessionDate < rhs.lastSessionDate : lhs.lastSessionDate > rhs.lastSessionDate
      }
    }
  }

  private func header(_ title: String, _ column: Column) -> some View {
    Button {
      sort.toggle(column)
    } label: {
      HStack(spacing: .stackTight) {
        Text(title)
        Image(systemName: sort.isAscending ? "chevron.up" : "chevron.down")
          .opacity(sort.column == column ? 1 : 0)
          .imageScale(.small)
      }
    }
    .buttonStyle(.plain)
    .help("Sort by \(title.lowercased())")
    .accessibilityLabel("Sort by \(title.lowercased())")
  }

  /// A sortable column of the task table.
  private enum Column {
    /// The task title.
    case title
    /// The owning provider's display name.
    case provider
    /// Focus time accumulated in the current scope.
    case total
    /// When the task's most recent session in scope ended.
    case lastSession
  }

  /// The table's active sort column and direction.
  private struct SortOrder {
    var column: Column
    var isAscending: Bool

    /// Reverses the direction when the active column is reselected, else sorts by the new column.
    ///
    /// A newly selected column starts descending, so the largest totals and most recent dates
    /// lead — the ordering a reader wants first from every column here.
    mutating func toggle(_ next: Column) {
      if column == next {
        isAscending.toggle()
      } else {
        column = next
        isAscending = false
      }
    }
  }
}

#if DEBUG
  #Preview {
    StatsTaskTable(rows: [
      StatsTaskRow(
        taskRef: nil, title: "Write the release notes", providerLabel: "Obsidian",
        totalSeconds: 5_400, lastSessionDate: .now),
      StatsTaskRow(
        taskRef: nil, title: "Review pull requests", providerLabel: "Reminders",
        totalSeconds: 3_000, lastSessionDate: .now.addingTimeInterval(-86_400)),
      StatsTaskRow(
        taskRef: nil, title: "Untracked", providerLabel: "—", totalSeconds: 900,
        lastSessionDate: .now.addingTimeInterval(-172_800)),
    ])
    .padding()
    .frame(width: 460)
  }
#endif
