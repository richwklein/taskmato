//
//  BrowseTasksButton.swift
//  Taskmato
//

import SwiftUI

/// A borderless "Browse Tasks…" affordance shown on the timer surfaces when no task is active.
///
/// Rendered in place of the active-task row on both the Timer destination and the companion
/// popover, so the two surfaces stay visually consistent and the dividers bracketing the row
/// keep a constant position whether or not a task is selected.
struct BrowseTasksButton: View {

  /// Invoked when the user clicks the button; routes to the task browser.
  var action: () -> Void

  var body: some View {
    Button(action: action) {
      Label(
        AppLabels.View.browseTask.title,
        systemImage: AppLabels.View.browseTask.systemImage
      )
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .foregroundStyle(.secondary)
  }
}

#Preview {
  BrowseTasksButton {}
    .padding()
}
