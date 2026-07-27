//
//  TaskStateButtonView.swift
//  Taskmato
//

import SwiftUI

/// The leading state control shared by ``TaskRowView`` and ``TaskCardView``.
///
/// Renders a filled restore circle for completed tasks, or a hover-toggling completion circle
/// for active tasks whose provider supports completion. Renders nothing for a read-only active
/// task. Binds `isHovered` so the active completion glyph reacts to pointer hover.
struct TaskStateButtonView: View {

  let presenter: TaskItemPresenter
  @Binding var isHovered: Bool

  var body: some View {
    if presenter.showsRestore, let onRestore = presenter.onRestore {
      Button(action: onRestore) {
        Image(systemName: "checkmark.circle.fill")
          .foregroundStyle(Color.accentColor)
      }
      .buttonStyle(.plain)
      .help(AppLabels.Tooltip.restore)
    } else if let onComplete = presenter.onComplete {
      Button(action: onComplete) {
        Image(systemName: isHovered ? "checkmark.circle" : "circle")
          .foregroundStyle(Color.accentColor)
      }
      .buttonStyle(.plain)
      .onHover { isHovered = $0 }
      .help(AppLabels.Tooltip.markAsCompleted)
    }
  }
}
