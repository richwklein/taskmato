//
//  TaskCompletionButton.swift
//  Taskmato
//

import SwiftUI

/// The hover-toggling completion control shared by the task picker's rows/cards and the
/// active-task surfaces.
///
/// Renders an accent-tinted outline circle that previews a checkmark on hover and invokes
/// ``action`` when clicked. Callers own the completion behavior (in-place completion for the
/// picker, confirm-then-stop for a live session) and the tooltip text; this view owns only the
/// glyph, hover, and accessibility so every surface's completion affordance looks identical.
struct TaskCompletionButton: View {

  /// Invoked when the user clicks to complete the task.
  let action: () -> Void
  /// Tooltip and VoiceOver label describing the completion action.
  var label: String
  /// Overrides the glyph size; `nil` inherits the surrounding font.
  var font: Font?
  /// Tracks pointer hover so the glyph can preview the checkmark.
  @Binding var isHovered: Bool

  var body: some View {
    Button(action: action) {
      Image(systemName: isHovered ? "checkmark.circle" : "circle")
        .font(font)
        .foregroundStyle(Color.accentColor)
    }
    .buttonStyle(.plain)
    .onHover { isHovered = $0 }
    .help(label)
    .accessibilityLabel(label)
  }
}
