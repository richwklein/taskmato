//
//  NotificationCenterAPI.swift
//  Taskmato
//

import UserNotifications

/// An abstraction over `UNUserNotificationCenter` for testability.
///
/// Conforming to `AnyObject` restricts adoption to reference types, matching the
/// singleton-style usage of `UNUserNotificationCenter`.
protocol NotificationCenterAPI: AnyObject {
  /// Returns the current notification authorization status without prompting.
  func authorizationStatus() async -> UNAuthorizationStatus
  /// Requests notification authorization; returns whether it was granted.
  func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
  /// Schedules a notification request; completion is fire-and-forget.
  func scheduleNotification(_ request: UNNotificationRequest)
  /// Assigns the delegate for foreground presentation and response callbacks.
  func setDelegate(_ delegate: (any UNUserNotificationCenterDelegate)?)
}

extension UNUserNotificationCenter: NotificationCenterAPI {
  func authorizationStatus() async -> UNAuthorizationStatus {
    await notificationSettings().authorizationStatus
  }

  func scheduleNotification(_ request: UNNotificationRequest) {
    add(request) { _ in }
  }

  func setDelegate(_ delegate: (any UNUserNotificationCenterDelegate)?) {
    self.delegate = delegate
  }
}
