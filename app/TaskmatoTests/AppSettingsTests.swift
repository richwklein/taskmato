//
//  AppSettingsTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

struct AppSettingsTests {

  /// Returns settings backed by an isolated, temporary UserDefaults suite.
  private func makeSettings() -> AppSettings {
    AppSettings(store: SettingsStore(defaults: UserDefaults(suiteName: UUID().uuidString)!))
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

  @Test func defaultSidebarVisibleIsTrue() {
    #expect(makeSettings().sidebarVisible == true)
  }

  // MARK: - Sort defaults

  @Test func defaultTaskSortFieldIsDueDate() {
    #expect(makeSettings().taskSortField == .dueDate)
  }

  @Test func defaultTaskSortDirectionIsAscending() {
    #expect(makeSettings().taskSortDirection == .ascending)
  }

  // MARK: - Sort persistence

  @Test func sortSettingsPersistAcrossInstances() {
    let defaults = UserDefaults(suiteName: UUID().uuidString)!
    let writer = AppSettings(store: SettingsStore(defaults: defaults))
    writer.taskSortField = .title
    writer.taskSortDirection = .descending
    let reader = AppSettings(store: SettingsStore(defaults: defaults))
    #expect(reader.taskSortField == .title)
    #expect(reader.taskSortDirection == .descending)
  }

  // MARK: - Notification settings defaults

  @Test func defaultSoundNameIsHero() {
    #expect(makeSettings().soundName == "Hero")
  }

  // MARK: - Notification settings persistence

  @Test func soundNamePersistsAcrossInstances() {
    let defaults = UserDefaults(suiteName: UUID().uuidString)!
    AppSettings(store: SettingsStore(defaults: defaults)).soundName = "Glass"
    #expect(AppSettings(store: SettingsStore(defaults: defaults)).soundName == "Glass")
  }

  // MARK: - Focus presets: normalization

  @Test func normalizedPresetsClampsOutOfRangeValues() {
    #expect(AppSettings.normalizedPresets([0, -5, 61, 500]) == [1, 60])
  }

  @Test func normalizedPresetsDropsDuplicates() {
    #expect(AppSettings.normalizedPresets([25, 25, 15, 15]) == [15, 25])
  }

  @Test func normalizedPresetsSortsAscending() {
    #expect(AppSettings.normalizedPresets([45, 15, 60, 25]) == [15, 25, 45, 60])
  }

  @Test func normalizedPresetsTrimsBeyondFive() {
    #expect(AppSettings.normalizedPresets([1, 2, 3, 4, 5, 6]).count == 5)
  }

  @Test func normalizedPresetsFallsBackToDefaultWhenEmpty() {
    #expect(AppSettings.normalizedPresets([]) == [25])
  }

  // MARK: - Focus presets: defaults & persistence

  @Test func defaultFocusPresetsMatchTheShippedSet() {
    #expect(makeSettings().focusPresets == [25])
  }

  @Test func focusPresetsPersistAcrossInstances() {
    let defaults = UserDefaults(suiteName: UUID().uuidString)!
    AppSettings(store: SettingsStore(defaults: defaults)).focusPresets = [10, 20, 30]
    #expect(AppSettings(store: SettingsStore(defaults: defaults)).focusPresets == [10, 20, 30])
  }

  // MARK: - Focus presets: setFocusPresets re-snap

  @Test func setFocusPresetsKeepsFocusMinutesWhenStillPresent() {
    let settings = makeSettings()
    settings.focusMinutes = 25
    settings.setFocusPresets([15, 25, 45, 60])
    #expect(settings.focusMinutes == 25)
  }

  @Test func setFocusPresetsResnapsToNearestRemainingPreset() {
    let settings = makeSettings()
    settings.focusMinutes = 25
    settings.setFocusPresets([15, 45, 60])
    #expect(settings.focusMinutes == 15)
  }

  @Test func setFocusPresetsResnapsExactTieToLowerValue() {
    let settings = makeSettings()
    settings.focusMinutes = 30
    settings.setFocusPresets([20, 40])
    #expect(settings.focusMinutes == 20)
  }

  @Test func setFocusPresetsNormalizesBeforeAssigning() {
    let settings = makeSettings()
    settings.setFocusPresets([100, 100, -5])
    #expect(settings.focusPresets == [1, 60])
  }

  // MARK: - Persistence

  @Test func settingPersistsAcrossInstances() {
    let suite = UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    let writer = AppSettings(store: SettingsStore(defaults: defaults))
    writer.focusMinutes = 42
    writer.soundEnabled = false
    writer.autoStartNextPhase = true

    let reader = AppSettings(store: SettingsStore(defaults: defaults))
    #expect(reader.focusMinutes == 42)
    #expect(reader.soundEnabled == false)
    #expect(reader.autoStartNextPhase == true)
  }
}
