//
//  ActiveTaskTitle.swift
//  Taskmato
//

import SwiftUI

/// The active task's title prefixed with its coloured priority mark, when the priority carries one.
///
/// Shared by every surface that names the active task (the slim popover line and the window's
/// timer strip) so priority-mark and markdown rendering stay identical across them.
func activeTaskDisplayTitle(for task: TaskItem) -> AttributedString {
  let mark = task.priority.mark
  guard !mark.isEmpty else { return task.markdownTitle }
  var prefix = AttributedString(mark + " ")
  prefix.swiftUI.foregroundColor = task.priority.accentColor
  return prefix + task.markdownTitle
}
