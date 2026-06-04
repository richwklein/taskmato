//
//  AppNotifications.swift
//  Taskmato
//

import Foundation

extension Notification.Name {
  /// Posted to switch to the Tasks tab without changing sidebar visibility.
  ///
  /// Used for plain tab-switches and auto-navigations after the active task is completed or
  /// cleared. The sidebar stays in whatever state the user last left it in.
  static let showTasksTab = Notification.Name("Taskmato.showTasksTab")

  /// Posted when the user explicitly wants to browse and pick a task.
  ///
  /// `MainWindowView` listens for this, expands the provider sidebar (so list scoping is
  /// visible), and switches to the Tasks tab.
  static let browseTasksAndPick = Notification.Name("Taskmato.browseTasksAndPick")

  /// Posted by the compact popover when the user taps the session stats row.
  ///
  /// `MainWindowView` listens for this and switches to the Stats tab.
  static let showStatsTab = Notification.Name("Taskmato.showStatsTab")

  /// Posted when a task is selected programmatically (URL handler, disambiguation) so the main
  /// window switches to the Timer tab and surfaces the selected task.
  static let showTimerTab = Notification.Name("Taskmato.showTimerTab")

  /// Posted by the URL handler to request that the main window be opened and brought to front.
  static let openMainWindow = Notification.Name("Taskmato.openMainWindow")
}
