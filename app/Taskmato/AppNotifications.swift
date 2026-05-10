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
}
