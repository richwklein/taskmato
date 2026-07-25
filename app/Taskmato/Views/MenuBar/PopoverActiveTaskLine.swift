//
//  PopoverActiveTaskLine.swift
//  Taskmato
//

import SwiftUI

/// A display-only line naming the active task in the slim menu-bar popover.
///
/// Shows an accent dot and the task title with its priority mark. Unlike the window's
/// ``ActiveTaskView`` it carries no complete/clear/swap actions — the popover is a
/// companion surface, and task mutation happens in the main window. Renders nothing when
/// no task is active, so the popover can show its own empty-state placeholder instead.
struct PopoverActiveTaskLine: View {

  var selectionStore: TaskSelectionStore

  var body: some View {
    if let task = selectionStore.activeTask {
      HStack(alignment: .firstTextBaseline, spacing: .contentGap) {
        Image(systemName: "circle.fill")
          .font(.caption2)
          .foregroundStyle(Color.accentColor)

        Text(activeTaskDisplayTitle(for: task))
          .font(.taskTitle)
          .lineLimit(1)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
  }
}

#Preview {
  let store = TaskSelectionStore()
  store.select(
    TaskItem(
      id: TaskRef(providerID: "adhoc", nativeID: UUID().uuidString),
      title: "Write the quarterly report",
      notes: nil,
      format: .plainText,
      priority: .high,
      dueDate: nil,
      scheduledDate: nil,
      startDate: nil,
      list: nil,
      section: nil,
      sourceURL: nil,
      completedAt: nil,
      createdAt: Date()
    )
  )
  return PopoverActiveTaskLine(selectionStore: store)
    .frame(width: 280)
    .padding()
}
