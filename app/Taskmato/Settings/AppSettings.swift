//
//  AppSettings.swift
//  Taskmato
//

import Foundation
import Observation

/// Persists user preferences for session and break durations.
///
/// All values are stored in `UserDefaults` and reflected immediately to any
/// observer. Duration changes take effect at the start of the next phase.
@Observable
final class AppSettings {

  /// Length of a focus interval, in minutes.
  var focusMinutes: Int {
    didSet { defaults.set(focusMinutes, forKey: Keys.focusMinutes) }
  }

  /// Length of a short break, in minutes.
  var shortBreakMinutes: Int {
    didSet { defaults.set(shortBreakMinutes, forKey: Keys.shortBreakMinutes) }
  }

  /// Length of a long break, in minutes.
  var longBreakMinutes: Int {
    didSet { defaults.set(longBreakMinutes, forKey: Keys.longBreakMinutes) }
  }

  /// Number of completed focus sessions before a long break is taken.
  var longBreakAfterSessions: Int {
    didSet { defaults.set(longBreakAfterSessions, forKey: Keys.longBreakAfterSessions) }
  }

  /// Whether a sound is played when a phase completes naturally.
  var soundEnabled: Bool {
    didSet { defaults.set(soundEnabled, forKey: Keys.soundEnabled) }
  }

  /// Whether a banner notification is shown when a phase completes naturally.
  var notificationsEnabled: Bool {
    didSet { defaults.set(notificationsEnabled, forKey: Keys.notificationsEnabled) }
  }

  /// Whether the next phase starts automatically on natural completion, or waits for the user to press Start.
  var autoStartNextPhase: Bool {
    didSet { defaults.set(autoStartNextPhase, forKey: Keys.autoStartNextPhase) }
  }

  /// Whether the app icon appears in the Dock and CMD+Tab switcher.
  ///
  /// Defaults to `false` — the app starts as a menu bar–only accessory. The user can
  /// enable the Dock icon in Settings to make the main window behave like a regular app.
  var showDockIcon: Bool {
    didSet { defaults.set(showDockIcon, forKey: Keys.showDockIcon) }
  }

  /// The display mode for the task picker (list rows or card grid).
  ///
  /// Defaults to `.grid`.
  var taskPickerLayout: TaskPickerLayout {
    didSet { defaults.set(taskPickerLayout.rawValue, forKey: Keys.taskPickerLayout) }
  }

  /// `focusMinutes` expressed as a `TimeInterval` in seconds.
  var focusDuration: TimeInterval { TimeInterval(focusMinutes * 60) }

  /// `shortBreakMinutes` expressed as a `TimeInterval` in seconds.
  var shortBreakDuration: TimeInterval { TimeInterval(shortBreakMinutes * 60) }

  /// `longBreakMinutes` expressed as a `TimeInterval` in seconds.
  var longBreakDuration: TimeInterval { TimeInterval(longBreakMinutes * 60) }

  private let defaults: UserDefaults

  /// Creates settings backed by the standard `UserDefaults` suite.
  convenience init() {
    self.init(defaults: .standard)
  }

  /// Creates settings backed by the provided `UserDefaults` instance. Pass a temporary suite in tests.
  init(defaults: UserDefaults) {
    self.defaults = defaults
    focusMinutes = defaults.integer(forKey: Keys.focusMinutes).nonZero ?? 25
    shortBreakMinutes = defaults.integer(forKey: Keys.shortBreakMinutes).nonZero ?? 5
    longBreakMinutes = defaults.integer(forKey: Keys.longBreakMinutes).nonZero ?? 15
    longBreakAfterSessions = defaults.integer(forKey: Keys.longBreakAfterSessions).nonZero ?? 4
    soundEnabled = defaults.object(forKey: Keys.soundEnabled) as? Bool ?? true
    notificationsEnabled = defaults.object(forKey: Keys.notificationsEnabled) as? Bool ?? true
    autoStartNextPhase = defaults.object(forKey: Keys.autoStartNextPhase) as? Bool ?? false
    showDockIcon = defaults.object(forKey: Keys.showDockIcon) as? Bool ?? false
    let rawLayout = defaults.string(forKey: Keys.taskPickerLayout)
    taskPickerLayout = rawLayout.flatMap(TaskPickerLayout.init) ?? .grid
  }

  private enum Keys {
    static let focusMinutes = "focusMinutes"
    static let shortBreakMinutes = "shortBreakMinutes"
    static let longBreakMinutes = "longBreakMinutes"
    static let longBreakAfterSessions = "longBreakAfterSessions"
    static let soundEnabled = "soundEnabled"
    static let notificationsEnabled = "notificationsEnabled"
    static let autoStartNextPhase = "autoStartNextPhase"
    static let showDockIcon = "showDockIcon"
    static let taskPickerLayout = "taskPickerLayout"
  }
}

extension Int {
  /// Returns `self` if greater than zero, otherwise `nil`.
  fileprivate var nonZero: Int? { self > 0 ? self : nil }
}
