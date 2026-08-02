//
//  ActiveTaskConfirm.swift
//  Taskmato
//

import SwiftUI

/// The destructive action awaiting inline confirmation on an active-task surface.
enum ActiveTaskConfirmAction {
  /// Mark the active task done and stop the session.
  case complete
  /// Clear the active task and stop the session.
  case clear

  /// Short label shown in the confirmation row.
  var prompt: String {
    switch self {
    case .complete: return "Stop & complete?"
    case .clear: return "Stop & clear?"
    }
  }

  /// Accessibility hint for the confirm button.
  var helpConfirm: String {
    switch self {
    case .complete: return "Stop timer and mark task done"
    case .clear: return "Stop timer and clear task"
    }
  }
}

/// The inline prompt that replaces the active-task line while a destructive action awaits
/// confirmation. Used on every surface so the stop-the-timer path reads identically.
struct ActiveTaskConfirmRow: View {

  /// The pending destructive action driving the prompt text and confirm tooltip.
  let action: ActiveTaskConfirmAction
  /// Font applied to the prompt text; callers vary this per surface.
  var font: Font = .callout
  /// Invoked when the user confirms the action.
  let onConfirm: () -> Void
  /// Invoked when the user cancels and returns to the normal row.
  let onCancel: () -> Void

  var body: some View {
    HStack(spacing: .contentGap) {
      Image(systemName: "exclamationmark.triangle")
        .font(.caption2)
        .foregroundStyle(.secondary)

      Text(action.prompt)
        .font(font)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)

      Button(action: onConfirm) {
        Image(systemName: "checkmark")
          .font(.caption2)
          .foregroundStyle(Color.accentColor)
      }
      .buttonStyle(.plain)
      .help(action.helpConfirm)
      .accessibilityLabel(action.helpConfirm)

      Button(action: onCancel) {
        Image(systemName: "xmark")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
      .buttonStyle(.plain)
      .help(AppLabels.Tooltip.cancel)
      .accessibilityLabel(AppLabels.Tooltip.cancel)
    }
  }
}

#if DEBUG
  #Preview {
    ActiveTaskConfirmRow(action: .complete, onConfirm: {}, onCancel: {})
      .padding()
      .frame(width: 280)
  }
#endif
