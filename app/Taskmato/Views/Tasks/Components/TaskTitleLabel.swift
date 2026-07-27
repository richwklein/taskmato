//
//  TaskTitleLabel.swift
//  Taskmato
//

import SwiftUI

/// The canonical "priority glyph + title" rendering shared by every task-naming surface.
///
/// Prefixes the task's coloured priority ``TaskPriority/icon`` (omitted for `.none`) before its
/// markdown title so priority reads identically in list rows, cards, the timer strip, the
/// popover companion, and the active-task view. `font` scales both glyph and title to the host
/// surface; `isCompleted` dims the title; `lineLimit` caps truncation.
///
/// This view is intentionally non-interactive — it carries no button or gesture — so surfaces
/// that make the whole task line tappable (the timer strip, the popover) can wrap it in a
/// `Button` without nested-control conflicts.
struct TaskTitleLabel: View {

  let task: TaskItem
  var isCompleted: Bool = false
  var lineLimit: Int = 2
  var font: Font = .taskTitle

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: .iconLabel) {
      PriorityGlyph(priority: task.priority, font: font)
      TaskMarkdownTitle(task: task, isCompleted: isCompleted, lineLimit: lineLimit, font: font)
    }
  }
}

#Preview {
  VStack(alignment: .leading, spacing: .contentGap) {
    ForEach(TaskPriority.allCases.reversed(), id: \.self) { priority in
      TaskTitleLabel(
        task: TaskItem(
          id: TaskRef(providerID: "local", nativeID: "\(priority.rawValue)"),
          title: "Priority \(priority)",
          notes: nil,
          format: .plainText,
          priority: priority,
          dueDate: nil
        )
      )
    }
  }
  .padding()
  .frame(width: 240)
}
