//
//  NotificationService.swift
//  Taskmato
//

import UserNotifications

/// Delivers local notifications when a Pomodoro phase completes naturally.
///
/// Registers itself as the `UNUserNotificationCenterDelegate` so that banners
/// appear even while the app is active (menu bar apps are always active).
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {

  private let center = UNUserNotificationCenter.current()

  override init() {
    super.init()
    center.delegate = self
  }

  /// Requests authorization if needed, then delivers a notification for the completed phase.
  ///
  /// Silently does nothing if the user has denied notification permission.
  func send(phase: SessionPhase) {
    center.requestAuthorization(options: [.alert]) { [weak self] granted, _ in
      guard granted, let self else { return }
      let content = UNMutableNotificationContent()
      switch phase {
      case .focus:
        content.title = "Focus session complete"
        content.body = "Time for a break."
      case .shortBreak:
        content.title = "Break's over"
        content.body = "Ready to focus again?"
      case .longBreak:
        content.title = "Long break done"
        content.body = "Time to get back to it."
      }
      let request = UNNotificationRequest(
        identifier: UUID().uuidString,
        content: content,
        trigger: nil
      )
      self.center.add(request)
    }
  }

  // MARK: - UNUserNotificationCenterDelegate

  /// Allows banners and sound to appear while the app is active.
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner])
  }
}
