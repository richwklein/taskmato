//
//  TaskDetailContextMenu.swift
//  Taskmato
//

import SwiftUI

/// Right-click (secondary-click) context menus for `TaskDetailView`'s task rows and cards.
/// Split from `TaskDetailView.swift` to keep that file under the repo's file-length limit.
extension TaskDetailView {

  /// The "Open in …" item naming `task`'s provider, or nothing when it carries no resolvable
  /// deep link (Local and ad-hoc tasks). Shared by both the active and completed context menus,
  /// since completed rows carry the same `sourceURL`.
  @ViewBuilder
  func openInProviderItem(for task: TaskItem) -> some View {
    if let link = TaskProviderLink(task: task, registry: registry) {
      Button {
        openInProvider(task)
      } label: {
        Label(link.label.title, systemImage: link.label.systemImage)
      }
    }
  }

  /// Context menu items shown on secondary-click (right-click or ctrl+click) of an active task row or card.
  @ViewBuilder
  func taskContextMenu(for task: TaskItem) -> some View {
    Button {
      select(task)
    } label: {
      Label(AppLabels.Task.track.title, systemImage: AppLabels.Task.track.systemImage)
    }
    Menu {
      ForEach(presenter.focusPresets, id: \.self) { minutes in
        Button("\(minutes) min") {
          startFocus(task, minutes: minutes)
        }
      }
    } label: {
      Label(
        AppLabels.FocusPreset.startFocus.title,
        systemImage: AppLabels.FocusPreset.startFocus.systemImage)
    }
    .disabled(!presenter.isIdle)
    if registry.writableProvider(for: task.id) != nil {
      Button {
        taskToEdit = task
        isEditingTask = true
      } label: {
        Label(AppLabels.Task.edit.title, systemImage: AppLabels.Task.edit.systemImage)
      }
    }
    openInProviderItem(for: task)
    Divider()
    if registry.writableProvider(for: task.id) != nil {
      Button {
        handleCut(task)
      } label: {
        Label(AppLabels.Task.cut.title, systemImage: AppLabels.Task.cut.systemImage)
      }
    }
    Button {
      copyToPasteboard(task)
    } label: {
      Label(AppLabels.Task.copy.title, systemImage: AppLabels.Task.copy.systemImage)
    }
    if registry.writableProvider(for: task.id) != nil {
      Button(role: .destructive) {
        activeDeleteCandidate = task
      } label: {
        Label(AppLabels.Task.delete.title, systemImage: AppLabels.Task.delete.systemImage)
      }
    }
    Divider()
    if registry.closableProvider(for: task.id) != nil {
      Button {
        handleComplete(task)
      } label: {
        Label(AppLabels.Task.complete.title, systemImage: AppLabels.Task.complete.systemImage)
      }
    }
  }

  /// Context menu items shown on secondary-click of a completed task row or card.
  @ViewBuilder
  func completedTaskContextMenu(for task: TaskItem) -> some View {
    if registry.writableProvider(for: task.id) != nil {
      Button {
        handleCut(task)
      } label: {
        Label(AppLabels.Task.cut.title, systemImage: AppLabels.Task.cut.systemImage)
      }
    }
    Button {
      copyToPasteboard(task)
    } label: {
      Label(AppLabels.Task.copy.title, systemImage: AppLabels.Task.copy.systemImage)
    }
    openInProviderItem(for: task)
    if registry.closableProvider(for: task.id) != nil {
      Button {
        handleRestore(task)
      } label: {
        Label(AppLabels.Task.restore.title, systemImage: AppLabels.Task.restore.systemImage)
      }
    }
    if registry.writableProvider(for: task.id) != nil {
      Button(role: .destructive) {
        activeDeleteCandidate = task
      } label: {
        Label(AppLabels.Task.delete.title, systemImage: AppLabels.Task.delete.systemImage)
      }
    }
  }
}
