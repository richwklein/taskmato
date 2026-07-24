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

  /// The name of the system sound file (without `.aiff` extension) played on phase completion.
  ///
  /// Defaults to `"Hero"`. Built-in values: `Hero`, `Glass`, `Tink`, `Sosumi`, `Ping`.
  var soundName: String {
    didSet { defaults.set(soundName, forKey: Keys.soundName) }
  }

  /// Whether phase-end alerts (banner and sound) are delivered.
  ///
  /// Acts as the master toggle — when `false`, no cues fire regardless of sub-toggle values.
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

  /// Whether the provider/list sidebar column is visible in the Tasks tab.
  ///
  /// Defaults to `false`; pick-flow entries (Browse Tasks…, swap-task) implicitly expand it.
  var sidebarVisible: Bool {
    didSet { defaults.set(sidebarVisible, forKey: Keys.sidebarVisible) }
  }

  /// The field used to sort tasks in all views. Defaults to `.dueDate`.
  var taskSortField: TaskSortField {
    didSet { defaults.set(taskSortField.rawValue, forKey: Keys.taskSortField) }
  }

  /// The sort direction applied to `taskSortField`. Defaults to `.ascending`.
  var taskSortDirection: TaskSortDirection {
    didSet { defaults.set(taskSortDirection.rawValue, forKey: Keys.taskSortDirection) }
  }

  /// The provider ID of the preferred writable provider for new ad-hoc tasks and the
  /// Add Task sheet, or `nil` to automatically select the first enabled writable provider.
  var defaultWritableProviderID: String? {
    didSet { defaults.set(defaultWritableProviderID, forKey: Keys.defaultWritableProviderID) }
  }

  /// Sidebar section IDs (a provider `id`, or `"stats"`) the user has collapsed.
  ///
  /// Empty by default, so every section starts expanded. Enabling or configuring a provider,
  /// and programmatic list selection, re-expands a section by removing its ID from this set.
  var collapsedSidebarSections: Set<String> {
    didSet {
      defaults.set(Array(collapsedSidebarSections), forKey: Keys.collapsedSidebarSections)
    }
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
    soundName = defaults.string(forKey: Keys.soundName) ?? "Hero"
    notificationsEnabled = defaults.object(forKey: Keys.notificationsEnabled) as? Bool ?? true
    autoStartNextPhase = defaults.object(forKey: Keys.autoStartNextPhase) as? Bool ?? false
    showDockIcon = defaults.object(forKey: Keys.showDockIcon) as? Bool ?? false
    let rawLayout = defaults.string(forKey: Keys.taskPickerLayout)
    taskPickerLayout = rawLayout.flatMap(TaskPickerLayout.init) ?? .grid
    sidebarVisible = defaults.object(forKey: Keys.sidebarVisible) as? Bool ?? false
    taskSortField =
      defaults.string(forKey: Keys.taskSortField).flatMap(TaskSortField.init) ?? .dueDate
    taskSortDirection =
      defaults.string(forKey: Keys.taskSortDirection).flatMap(TaskSortDirection.init) ?? .ascending
    defaultWritableProviderID = defaults.string(forKey: Keys.defaultWritableProviderID)
    collapsedSidebarSections = Set(
      defaults.stringArray(forKey: Keys.collapsedSidebarSections) ?? [])
  }

  private enum Keys {
    static let focusMinutes = "focusMinutes"
    static let shortBreakMinutes = "shortBreakMinutes"
    static let longBreakMinutes = "longBreakMinutes"
    static let longBreakAfterSessions = "longBreakAfterSessions"
    static let soundEnabled = "soundEnabled"
    static let soundName = "soundName"
    static let notificationsEnabled = "notificationsEnabled"
    static let autoStartNextPhase = "autoStartNextPhase"
    static let showDockIcon = "showDockIcon"
    static let taskPickerLayout = "taskPickerLayout"
    static let sidebarVisible = "taskRegistry.sidebarVisible"
    static let taskSortField = "taskSort.field"
    static let taskSortDirection = "taskSort.direction"
    static let defaultWritableProviderID = "tasks.defaultWritableProviderID"
    static let collapsedSidebarSections = "sidebar.collapsedSections"
  }
}

extension Int {
  /// Returns `self` if greater than zero, otherwise `nil`.
  fileprivate var nonZero: Int? { self > 0 ? self : nil }
}
