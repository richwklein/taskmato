//
//  TaskMarkdownTitle.swift
//  Taskmato
//

import SwiftUI

/// Renders a task title with inline-only markdown when `format` is `.markdown`, or as plain text.
///
/// Used in task rows and cards wherever the title appears. Pass `isCompleted` to switch to
/// secondary foreground color; use `lineLimit` to cap truncation per layout context.
struct TaskMarkdownTitle: View {

  let task: TaskItem
  var isCompleted: Bool = false
  var lineLimit: Int = 2

  var body: some View {
    Text(task.markdownTitle)
      .font(.taskTitle)
      .foregroundStyle(isCompleted ? .secondary : .primary)
      .lineLimit(lineLimit)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}
