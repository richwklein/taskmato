//
//  TaskStateButtonView.swift
//  Taskmato
//

import SwiftUI

/// The leading state control used by ``TaskRowView``.
///
/// Renders a filled restore circle for completed tasks, or a hover-toggling completion circle
/// for active tasks whose provider supports completion. Renders nothing for a read-only active
/// task. Binds `isHovered` so the active completion glyph reacts to pointer hover.
struct TaskStateButtonView: View {

  let presenter: TaskItemPresenter
  @Binding var isHovered: Bool

  /// Set by `List` on an emphasized selected row, where accent-on-accent would disappear.
  @Environment(\.backgroundProminence) private var prominence

  var body: some View {
    if presenter.showsRestore, let onRestore = presenter.onRestore {
      Button(action: onRestore) {
        Image(systemName: "checkmark.circle.fill")
          .foregroundStyle(prominence.accent(.accentColor))
      }
      .buttonStyle(.plain)
      .help(AppLabels.Tooltip.restore)
      .accessibilityLabel(AppLabels.Tooltip.restore)
    } else if let onComplete = presenter.onComplete {
      TaskCompletionButton(
        action: onComplete, label: AppLabels.Tooltip.markAsCompleted, isHovered: $isHovered)
    }
  }
}
