//
//  TaskMetadataLabel.swift
//  Taskmato
//

import SwiftUI

/// A task's one-line metadata: the due date for active tasks, or the completed-relative
/// subtitle for completed ones.
///
/// A view of its own rather than a slot inside ``TaskRowView`` so it reads
/// `\.backgroundProminence` at its own position, the way ``PriorityGlyph`` does — an overdue
/// date is an explicit red that a selected row's accent fill would otherwise swallow.
struct TaskMetadataLabel: View {

  let presenter: TaskItemPresenter
  /// The clock the due date is computed against.
  let now: Date

  /// Set by `List` on an emphasized selected row, where the overdue tint stops reading.
  @Environment(\.backgroundProminence) private var prominence

  var body: some View {
    if let display = presenter.dueDisplay(now: now) {
      HStack(spacing: .iconLabel) {
        if display.urgency == .overdue {
          Image(systemName: "flag.fill")
            .accessibilityHidden(true)
        }
        Text(display.text)
      }
      .font(.taskMetadata)
      .foregroundStyle(color(for: display.urgency))
      .help(display.tooltipText)
      .accessibilityLabel(display.accessibleText)
    } else if presenter.isCompleted {
      Text(presenter.completedSubtitle)
        .font(.taskMetadata)
        .foregroundStyle(.tertiary)
    }
  }

  private func color(for urgency: DueDateDisplay.Urgency) -> Color {
    switch urgency {
    case .overdue: return prominence.accent(.dueUrgent)
    case .today: return .primary
    case .upcoming: return .secondary
    }
  }
}
