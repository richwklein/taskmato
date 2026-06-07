//
//  SessionPhaseNotificationTests.swift
//  TaskmatoTests
//

import Testing

@testable import Taskmato

struct SessionPhaseNotificationTests {

  // MARK: - notificationTitle

  @Test func focusNotificationTitle() {
    #expect(SessionPhase.focus.notificationTitle == "Focus session complete")
  }

  @Test func shortBreakNotificationTitle() {
    #expect(SessionPhase.shortBreak.notificationTitle == "Break's over")
  }

  @Test func longBreakNotificationTitle() {
    #expect(SessionPhase.longBreak.notificationTitle == "Long break done")
  }

  // MARK: - notificationBody

  @Test func focusNotificationBody() {
    #expect(SessionPhase.focus.notificationBody == "Time for a break.")
  }

  @Test func shortBreakNotificationBody() {
    #expect(SessionPhase.shortBreak.notificationBody == "Ready to focus again?")
  }

  @Test func longBreakNotificationBody() {
    #expect(SessionPhase.longBreak.notificationBody == "Time to get back to it.")
  }

}
