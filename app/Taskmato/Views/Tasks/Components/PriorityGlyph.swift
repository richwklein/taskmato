//
//  PriorityGlyph.swift
//  Taskmato
//

import SwiftUI

/// The coloured priority indicator shared by every task-naming surface.
///
/// Renders the task priority's ``TaskPriority/icon`` tinted by its ``TaskPriority/accentColor``,
/// or nothing for `.none`. `font` scales the glyph to match the host surface's title. Used as a
/// hanging leading marker beside a task's text block (``TaskRowView``, ``TaskCardView``,
/// ``ActiveTaskView``), so priority reads identically everywhere.
struct PriorityGlyph: View {

  let priority: TaskPriority
  var font: Font = .taskTitle

  var body: some View {
    if let icon = priority.icon {
      Image(systemName: icon)
        .foregroundStyle(priority.accentColor)
        .font(font)
    }
  }
}
