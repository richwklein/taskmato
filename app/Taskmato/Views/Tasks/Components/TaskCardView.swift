//
//  TaskCardView.swift
//  Taskmato
//

import SwiftUI

/// A card-style representation of a task for the grid layout in the task picker.
///
/// Use ``TaskItemKind`` to distinguish active and completed tasks. Pass `lineage` when the
/// picker is in cross-provider flat mode (Today or search) to show the task's origin. All
/// non-layout logic lives in ``TaskItemPresenter``; this view only arranges the slots.
struct TaskCardView: View {

  let task: TaskItem
  let kind: TaskItemKind
  var lineage: TaskLineage?

  /// Whether this card is the current grid selection (issue #546).
  var isSelected: Bool = false
  /// Whether task content currently owns keyboard focus.
  var isSelectionFocused: Bool = false

  @State private var completionHover = false
  @State private var cardHover = false
  @State private var showDeleteConfirmation = false

  private var presenter: TaskItemPresenter {
    TaskItemPresenter(task: task, kind: kind, lineage: lineage)
  }

  var body: some View {
    HStack(alignment: .top, spacing: .iconLabel) {
      TaskStateButtonView(presenter: presenter, isHovered: $completionHover)
      HStack(alignment: .firstTextBaseline, spacing: .iconLabel) {
        PriorityGlyph(priority: task.priority)
        VStack(alignment: .leading, spacing: .rowVertical) {
          TaskMarkdownTitle(task: task, isCompleted: presenter.isCompleted, lineLimit: 3)
          if let notes = task.notes {
            TaskNoteView(notes: notes, format: task.format)
              .lineLimit(2)
          }
          metadata
          if let lineage = presenter.displayLineage {
            TaskLineageRow(lineage: lineage)
          }
          Spacer(minLength: 0)
        }
      }
      TaskDeleteButtonView(
        presenter: presenter, isHovered: cardHover, showConfirmation: $showDeleteConfirmation)
    }
    .padding(.cardPadding)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(
      RoundedRectangle.card
        .fill(cardBackground)
    )
    .overlay(
      RoundedRectangle.card
        .strokeBorder(Color.clear, lineWidth: 2)
    )
    .contentShape(RoundedRectangle.card)
    .onHover { cardHover = $0 }
    .accessibilityAddTraits(isSelected ? .isSelected : [])
    .confirmationDialog(
      "Delete this task permanently?", isPresented: $showDeleteConfirmation
    ) {
      Button("Delete", role: .destructive) { presenter.onDelete?() }
      Button("Cancel", role: .cancel) {}
    }
  }

  private var cardBackground: Color {
    guard isSelected else { return .cardSurface }
    return isSelectionFocused ? .activeSelection : .inactiveSelection
  }

  /// The due date (active tasks) or completed-relative subtitle (completed tasks). The card's
  /// date format includes the year, distinguishing it from the row's compact form.
  @ViewBuilder
  private var metadata: some View {
    if let due = presenter.dueDate {
      Text(due, format: .dateTime.month(.abbreviated).day().year())
        .font(.taskMetadata)
        .foregroundStyle(presenter.dueIsUrgent ? Color.dueUrgent : Color.secondary)
    } else if presenter.isCompleted {
      Text(presenter.completedSubtitle)
        .font(.taskMetadata)
        .foregroundStyle(.tertiary)
    }
  }
}

#if DEBUG
  #Preview {
    let task = TaskItem(
      id: TaskRef(providerID: "local", nativeID: "1"),
      title: "Create a support metrics dashboard and wiki",
      notes: "Build out a dashboard of our support metrics once we have some statistics.",
      format: .plainText,
      priority: .high,
      dueDate: Calendar.current.date(byAdding: .day, value: -3, to: .now)
    )
    TaskCardView(task: task, kind: .active(onComplete: {}, onDelete: {}))
      .padding()
      .frame(width: 200)
  }
#endif
