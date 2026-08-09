//
//  TaskDeleteButtonView.swift
//  Taskmato
//

import SwiftUI

/// The trailing permanent-delete control shared by ``TaskRowView`` and ``TaskCardView``.
///
/// Renders for an active or completed task on a writable provider, revealing on hover or keyboard focus;
/// requesting deletion sets `showConfirmation`, which the host view surfaces via its confirmation
/// dialog. Renders nothing for tasks that cannot be deleted.
///
/// When deletable, the slot keeps its layout footprint at all times and toggles only opacity on
/// hover/focus, so the surrounding title never reflows as the button appears. The control stays
/// hit-testable and exposed to accessibility regardless of visual reveal state, so keyboard and
/// assistive-technology users can always reach it — only sighted pointer users need the hover to
/// discover it.
struct TaskDeleteButtonView: View {

  let presenter: TaskItemPresenter
  let isHovered: Bool
  @Binding var showConfirmation: Bool

  @FocusState private var isFocused: Bool

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
      .focused($isFocused)
      .opacity(isHovered || isFocused ? 1 : 0)
    }
  }
}
