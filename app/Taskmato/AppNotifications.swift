//
//  AppNotifications.swift
//  Taskmato
//

import Foundation

extension Notification.Name {
  /// Posted by the compact popover when the user taps "Browse Tasks…".
  ///
  /// `MainWindowView` listens for this and switches to the Tasks tab.
  static let showTasksTab = Notification.Name("Taskmato.showTasksTab")

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
