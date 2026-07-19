//
//  NotificationService.swift
//  Taskmato
//

import UserNotifications

/// Delivers Focus-aware phase-end alerts: banner and sound.
///
/// Banner and sound ride the notification delivery path so macOS Focus modes and Do Not
/// Disturb gate them uniformly.  Authorization is requested once at launch and cached so
/// the hot path (`send`) is synchronous.
@Observable
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {

  /// The most recently cached notification authorization status.
  ///
  /// Starts as `.notDetermined`. Refreshed at four touchpoints: launch,
  /// `becomeActive`, the user toggling the master alert switch, and before `send()`.
  private(set) var authStatus: UNAuthorizationStatus = .notDetermined

  private let settings: AppSettings
  private let center: NotificationCenterAPI

  /// Creates a service wired to the given dependencies.
  ///
  /// - Parameters:
  ///   - settings: App-wide user preferences.
  ///   - center: Notification center abstraction; defaults to `UNUserNotificationCenter.current()`.
  init(
    settings: AppSettings,
    center: NotificationCenterAPI = UNUserNotificationCenter.current()
  ) {
    self.settings = settings
    self.center = center
    super.init()
    center.setDelegate(self)
  }

  /// Requests OS authorization when status is `.notDetermined`, then refreshes the cache.
  ///
  /// Safe to call repeatedly — the OS only shows the prompt once; this method gates on
  /// `.notDetermined` to avoid redundant calls on `authorized` or `denied` paths.
  func requestAuthorizationIfNeeded() async {
    let current = await center.authorizationStatus()
    if current == .notDetermined {
      _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }
    await refreshAuthStatus()
  }

  /// Reads the current authorization status from the OS and caches it in `authStatus`.
  func refreshAuthStatus() async {
    authStatus = await center.authorizationStatus()
  }

  /// Schedules a phase-end notification if authorized and alerts are enabled.
  ///
  /// Synchronous on the hot path — authorization gating uses the cached `authStatus`.
  /// Sound is attached to the notification content so Focus and DND suppress it alongside
  /// the banner.
  func send(phase: SessionPhase) {
    guard authStatus == .authorized, settings.notificationsEnabled else { return }
    let content = UNMutableNotificationContent()
    content.title = phase.notificationTitle
    content.body = phase.notificationBody
    if settings.soundEnabled {
      content.sound = UNNotificationSound(
        named: UNNotificationSoundName(rawValue: "\(settings.soundName).aiff"))
    }
    content.userInfo = ["phase": phase.rawValue]
    let request = UNNotificationRequest(
      identifier: UUID().uuidString, content: content, trigger: nil)
    center.scheduleNotification(request)
  }

  // MARK: - UNUserNotificationCenterDelegate

  /// Allows banners and sound to appear while the app is active.
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .sound])
  }

  /// Handles a tap on a delivered notification.
  ///
  /// Calling `completionHandler` without activating the app prevents macOS from
  /// applying its default "bring app to foreground" behavior, which would open the
  /// main Window scene unexpectedly for a menu-bar-only app.
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    completionHandler()
  }
}
