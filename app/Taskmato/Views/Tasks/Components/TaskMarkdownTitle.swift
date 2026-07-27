//
//  TaskMarkdownTitle.swift
//  Taskmato
//

import SwiftUI

/// Renders a task title with inline-only markdown when `format` is `.markdown`, or as plain text.
///
/// Used wherever a task title appears — composed into ``TaskTitleLabel`` alongside the priority
/// glyph. Pass `isCompleted` to switch to secondary foreground color, `lineLimit` to cap
/// truncation, and `font` to match the surrounding surface (defaults to ``Font/taskTitle``).
struct TaskMarkdownTitle: View {

  let task: TaskItem
  var isCompleted: Bool = false
  var lineLimit: Int = 2
  var font: Font = .taskTitle

  var body: some View {
    Text(task.markdownTitle)
      .font(font)
      .foregroundStyle(isCompleted ? .secondary : .primary)
      .lineLimit(lineLimit)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}
