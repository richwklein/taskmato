//
//  AppSettingsTests.swift
//  TaskmatoTests
//

import Testing
@testable import Taskmato
import Foundation

struct AppSettingsTests {

    /// Returns settings backed by an isolated, temporary UserDefaults suite.
    private func makeSettings() -> AppSettings {
        AppSettings(defaults: UserDefaults(suiteName: UUID().uuidString)!)
    }

    // MARK: - Duration conversions

    @Test func focusDurationIsMinutesInSeconds() {
        let settings = makeSettings()
        settings.focusMinutes = 30
        #expect(settings.focusDuration == 30 * 60)
    }

    @Test func shortBreakDurationIsMinutesInSeconds() {
        let settings = makeSettings()
        settings.shortBreakMinutes = 10
        #expect(settings.shortBreakDuration == 10 * 60)
    }

    @Test func longBreakDurationIsMinutesInSeconds() {
        let settings = makeSettings()
        settings.longBreakMinutes = 20
        #expect(settings.longBreakDuration == 20 * 60)
    }

    // MARK: - Default values

    @Test func defaultFocusIsPositive() {
        #expect(makeSettings().focusMinutes > 0)
    }

    @Test func defaultShortBreakIsPositive() {
        #expect(makeSettings().shortBreakMinutes > 0)
    }

    @Test func defaultLongBreakIsPositive() {
        #expect(makeSettings().longBreakMinutes > 0)
    }

    @Test func defaultLongBreakIsLongerThanShortBreak() {
        let settings = makeSettings()
        #expect(settings.longBreakMinutes > settings.shortBreakMinutes)
    }

    @Test func defaultLongBreakAfterSessionsIsFour() {
        #expect(makeSettings().longBreakAfterSessions == 4)
    }

    // MARK: - Boolean defaults

    @Test func defaultSoundEnabledIsTrue() {
        #expect(makeSettings().soundEnabled == true)
    }

    @Test func defaultNotificationsEnabledIsTrue() {
        #expect(makeSettings().notificationsEnabled == true)
    }

    @Test func defaultAutoStartNextPhaseIsFalse() {
        #expect(makeSettings().autoStartNextPhase == false)
    }

    // MARK: - Persistence

    @Test func settingPersistsAcrossInstances() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        let writer = AppSettings(defaults: defaults)
        writer.focusMinutes = 42
        writer.soundEnabled = false
        writer.autoStartNextPhase = true

        let reader = AppSettings(defaults: defaults)
        #expect(reader.focusMinutes == 42)
        #expect(reader.soundEnabled == false)
        #expect(reader.autoStartNextPhase == true)
    }
}
