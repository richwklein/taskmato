//
//  TaskMarkdownTitle.swift
//  Taskmato
//

import SwiftUI

/// Renders a task title with inline-only markdown when `format` is `.markdown`, or as plain text.
///
/// Used wherever a task title appears — paired with ``PriorityGlyph`` as a hanging leading
/// marker (``TaskRowView``, ``ActiveTaskView``). Pass `isCompleted` to switch
/// to secondary foreground color, `lineLimit` to cap truncation, and `font` to match the
/// surrounding surface (defaults to ``Font/taskTitle``).
struct TaskMarkdownTitle: View {

  let task: TaskItem
  var isCompleted: Bool = false
  var lineLimit: Int = 2
  var font: Font = .taskTitle
  /// When `true` the title greedily fills its container so trailing controls align to the far
  /// edge; when `false` it sizes to content (still truncating under pressure) so an adjacent
  /// element can sit snug against it, as the timer strip's inline countdown does.
  var fill: Bool = true

  var body: some View {
    Text(task.markdownTitle)
      .font(font)
      .foregroundStyle(isCompleted ? .secondary : .primary)
      .lineLimit(lineLimit)
      .frame(maxWidth: fill ? .infinity : nil, alignment: .leading)
      .help(task.title)
  }
}
