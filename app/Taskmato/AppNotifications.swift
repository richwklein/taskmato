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

  /// Posted by `AppDelegate.application(_:open:)` when macOS routes a URL to the app.
  ///
  /// The `object` of the notification is the `URL`. `MenuBarExtra` content does not
  /// receive `.onOpenURL` reliably, so routing through `NotificationCenter` is required.
  static let openURL = Notification.Name("Taskmato.openURL")
}
