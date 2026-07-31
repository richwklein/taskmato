//
//  TaskDeleteButtonView.swift
//  Taskmato
//

import SwiftUI

/// The trailing permanent-delete control shared by ``TaskRowView`` and ``TaskCardView``.
///
/// Renders for a completed task on a writable provider, revealing on hover; requesting deletion
/// sets `showConfirmation`, which the host view surfaces via its confirmation dialog. Renders
/// nothing for tasks that cannot be deleted.
///
/// When deletable, the slot keeps its layout footprint at all times and toggles only opacity and
/// hit-testing on hover, so the surrounding title never reflows as the button appears.
struct TaskDeleteButtonView: View {

  let presenter: TaskItemPresenter
  let isHovered: Bool
  @Binding var showConfirmation: Bool

  var body: some View {
    if presenter.canDelete {
      Button {
        showConfirmation = true
      } label: {
        Image(systemName: "trash")
          .foregroundStyle(.secondary)
      }
      .buttonStyle(.plain)
      .help(AppLabels.Tooltip.deletePermanently)
      .accessibilityLabel(AppLabels.Tooltip.deletePermanently)
      .opacity(isHovered ? 1 : 0)
      .allowsHitTesting(isHovered)
      .accessibilityHidden(!isHovered)
    }
  }
}
