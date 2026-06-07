//
//  NotificationServiceTests.swift
//  TaskmatoTests
//

import Testing
import UserNotifications

@testable import Taskmato

// MARK: - Fakes

/// A controllable stand-in for UNUserNotificationCenter.
private final class FakeNotificationCenter: NotificationCenterAPI {
  var stubbedStatus: UNAuthorizationStatus
  private(set) var requestAuthorizationCallCount = 0
  private(set) var scheduledRequests: [UNNotificationRequest] = []

  init(status: UNAuthorizationStatus = .notDetermined) {
    self.stubbedStatus = status
  }

  func authorizationStatus() async -> UNAuthorizationStatus { stubbedStatus }

  func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
    requestAuthorizationCallCount += 1
    return stubbedStatus == .authorized
  }

  func scheduleNotification(_ request: UNNotificationRequest) {
    scheduledRequests.append(request)
  }

  func setDelegate(_ delegate: (any UNUserNotificationCenterDelegate)?) {}
}

// MARK: - Helpers

private struct ServiceContext {
  let service: NotificationService
  let center: FakeNotificationCenter
  let settings: AppSettings
}

@MainActor
private func makeContext(status: UNAuthorizationStatus = .notDetermined) -> ServiceContext {
  let center = FakeNotificationCenter(status: status)
  let settings = AppSettings(defaults: UserDefaults(suiteName: UUID().uuidString)!)
  let service = NotificationService(settings: settings, center: center)
  return ServiceContext(service: service, center: center, settings: settings)
}

// MARK: - Tests

@MainActor
struct NotificationServiceTests {

  // MARK: - Initial state

  @Test func cachedStatusStartsAsNotDetermined() {
    let ctx = makeContext(status: .authorized)
    #expect(ctx.service.authStatus == .notDetermined)
  }

  // MARK: - Auth request gate

  @Test func requestsAuthorizationWhenNotDetermined() async {
    let ctx = makeContext(status: .notDetermined)
    await ctx.service.requestAuthorizationIfNeeded()
    #expect(ctx.center.requestAuthorizationCallCount == 1)
  }

  @Test func skipsAuthorizationRequestWhenAuthorized() async {
    let ctx = makeContext(status: .authorized)
    await ctx.service.requestAuthorizationIfNeeded()
    #expect(ctx.center.requestAuthorizationCallCount == 0)
  }

  @Test func skipsAuthorizationRequestWhenDenied() async {
    let ctx = makeContext(status: .denied)
    await ctx.service.requestAuthorizationIfNeeded()
    #expect(ctx.center.requestAuthorizationCallCount == 0)
  }

  // MARK: - Status refresh

  @Test func refreshAuthStatusUpdatesCachedStatus() async {
    let ctx = makeContext(status: .authorized)
    ctx.center.stubbedStatus = .authorized
    await ctx.service.refreshAuthStatus()
    #expect(ctx.service.authStatus == .authorized)
  }

  @Test func refreshAuthStatusReflectsDenied() async {
    let ctx = makeContext(status: .denied)
    await ctx.service.refreshAuthStatus()
    #expect(ctx.service.authStatus == .denied)
  }

  // MARK: - send gating

  @Test func sendDoesNothingWhenNotAuthorized() async {
    let ctx = makeContext(status: .denied)
    await ctx.service.refreshAuthStatus()
    ctx.service.send(phase: .focus)
    #expect(ctx.center.scheduledRequests.isEmpty)
  }

  @Test func sendDoesNothingWhenNotificationsDisabled() async {
    let ctx = makeContext(status: .authorized)
    await ctx.service.refreshAuthStatus()
    ctx.settings.notificationsEnabled = false
    ctx.service.send(phase: .focus)
    #expect(ctx.center.scheduledRequests.isEmpty)
  }

  @Test func sendSchedulesRequestWhenAuthorized() async {
    let ctx = makeContext(status: .authorized)
    await ctx.service.refreshAuthStatus()
    ctx.service.send(phase: .focus)
    #expect(ctx.center.scheduledRequests.count == 1)
  }

  // MARK: - Sound attachment

  @Test func sendAttachesSoundWhenSoundEnabled() async {
    let ctx = makeContext(status: .authorized)
    await ctx.service.refreshAuthStatus()
    ctx.settings.soundEnabled = true
    ctx.service.send(phase: .focus)
    #expect(ctx.center.scheduledRequests.first?.content.sound != nil)
  }

  @Test func sendDoesNotAttachSoundWhenSoundDisabled() async {
    let ctx = makeContext(status: .authorized)
    await ctx.service.refreshAuthStatus()
    ctx.settings.soundEnabled = false
    ctx.service.send(phase: .focus)
    #expect(ctx.center.scheduledRequests.first?.content.sound == nil)
  }

  // MARK: - Notification content

  @Test func sendEmbedsPhaseRawValueInUserInfo() async {
    let ctx = makeContext(status: .authorized)
    await ctx.service.refreshAuthStatus()
    ctx.service.send(phase: .shortBreak)
    let userInfo = ctx.center.scheduledRequests.first?.content.userInfo
    #expect(userInfo?["phase"] as? String == SessionPhase.shortBreak.rawValue)
  }

}
