//
//  AppDestination.swift
//  Taskmato
//

import Foundation

/// A destination in the window-first shell's universal sidebar.
///
/// Models every navigable surface as one value: the pinned Timer and Today rows, a specific
/// provider list, and a stats scope. Owned by ``MainNavigation``; task-scope destinations
/// (`.today` / `.list`) are forwarded one-way into the task-scope selection sink so the
/// task-query layer never learns that Timer or Stats exist (design doc 0008, D4).
enum AppDestination: Hashable {

  /// The Timer surface — focus/break controls and the active task.
  case timer

  /// The Today smart view — tasks due on or before the end of today, across all providers.
  case today

  /// A specific provider list.
  case list(SelectedList)

  /// The Stats surface scoped to a time window.
  case stats(StatScope)

  /// The equivalent task-scope selection, or `nil` for non-task destinations (Timer, Stats).
  var taskSelection: SidebarSelection? {
    switch self {
    case .today: return .today
    case .list(let selectedList): return .list(selectedList)
    case .timer, .stats: return nil
    }
  }

  /// Builds the destination for a task-scope selection, or `nil` when there is no selection.
  /// - Parameter taskSelection: A sidebar selection to mirror into a destination.
  init?(taskSelection: SidebarSelection?) {
    switch taskSelection {
    case .today: self = .today
    case .list(let selectedList): self = .list(selectedList)
    case nil: return nil
    }
  }
}
