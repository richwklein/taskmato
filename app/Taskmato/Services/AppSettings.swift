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
    didSet { store[SettingsStore.Keys.focusMinutes] = focusMinutes }
  }

  /// Ordered focus-length presets, in minutes, offered as quick-select chips on the timer,
  /// in the menu-bar popover, and in a task's "Start Focus" submenu.
  ///
  /// `focusMinutes` holds the currently-selected length; presets are the values it jumps
  /// between. This setter is persistence-only — it mirrors `focusMinutes`'s `didSet` and does
  /// no normalization, so it never re-enters `@Observable`. Every mutation should go through
  /// ``setFocusPresets(_:)`` instead of assigning this property directly, so the stored list
  /// stays normalized.
  var focusPresets: [Int] {
    didSet { store[SettingsStore.Keys.focusPresets] = focusPresets }
  }

  /// Length of a short break, in minutes.
  var shortBreakMinutes: Int {
    didSet { store[SettingsStore.Keys.shortBreakMinutes] = shortBreakMinutes }
  }

  /// Length of a long break, in minutes.
  var longBreakMinutes: Int {
    didSet { store[SettingsStore.Keys.longBreakMinutes] = longBreakMinutes }
  }

  /// Number of completed focus sessions before a long break is taken.
  var longBreakAfterSessions: Int {
    didSet { store[SettingsStore.Keys.longBreakAfterSessions] = longBreakAfterSessions }
  }

  /// Whether a sound is played when a phase completes naturally.
  var soundEnabled: Bool {
    didSet { store[SettingsStore.Keys.soundEnabled] = soundEnabled }
  }

  /// The name of the system sound file (without `.aiff` extension) played on phase completion.
  ///
  /// Defaults to `"Hero"`. Built-in values: `Hero`, `Glass`, `Tink`, `Sosumi`, `Ping`.
  var soundName: String {
    didSet { store[SettingsStore.Keys.soundName] = soundName }
  }

  /// Whether phase-end alerts (banner and sound) are delivered.
  ///
  /// Acts as the master toggle — when `false`, no cues fire regardless of sub-toggle values.
  var notificationsEnabled: Bool {
    didSet { store[SettingsStore.Keys.notificationsEnabled] = notificationsEnabled }
  }

  /// Whether the next phase starts automatically on natural completion, or waits for the user to press Start.
  var autoStartNextPhase: Bool {
    didSet { store[SettingsStore.Keys.autoStartNextPhase] = autoStartNextPhase }
  }

  /// Whether the provider/list sidebar column is visible in the window-first shell.
  ///
  /// Defaults to `true` — the sidebar is the app's primary navigation (design doc 0008, D9;
  /// reverses design doc 0003 decision 4, whose tab-layout rationale no longer applies).
  var sidebarVisible: Bool {
    didSet { store[SettingsStore.Keys.sidebarVisible] = sidebarVisible }
  }

  /// The field used to sort tasks in all views. Defaults to `.dueDate`.
  var taskSortField: TaskSortField {
    didSet { store[SettingsStore.Keys.taskSortField] = taskSortField }
  }

  /// The sort direction applied to `taskSortField`. Defaults to `.ascending`.
  var taskSortDirection: TaskSortDirection {
    didSet { store[SettingsStore.Keys.taskSortDirection] = taskSortDirection }
  }

  /// The provider ID of the preferred writable provider for new ad-hoc tasks and the
  /// Add Task sheet, or `nil` to automatically select the first enabled writable provider.
  var defaultWritableProviderID: ProviderID? {
    didSet { store[SettingsStore.Keys.defaultWritableProviderID] = defaultWritableProviderID }
  }

  /// Sidebar section IDs (a provider `id`, or `"stats"`) the user has collapsed.
  ///
  /// Empty by default, so every section starts expanded. Enabling or configuring a provider,
  /// and programmatic list selection, re-expands a section by removing its ID from this set.
  var collapsedSidebarSections: Set<String> {
    didSet { store[SettingsStore.Keys.collapsedSidebarSections] = collapsedSidebarSections }
  }

  /// `focusMinutes` expressed as a `TimeInterval` in seconds.
  var focusDuration: TimeInterval { TimeInterval(focusMinutes * 60) }

  /// `shortBreakMinutes` expressed as a `TimeInterval` in seconds.
  var shortBreakDuration: TimeInterval { TimeInterval(shortBreakMinutes * 60) }

  /// `longBreakMinutes` expressed as a `TimeInterval` in seconds.
  var longBreakDuration: TimeInterval { TimeInterval(longBreakMinutes * 60) }

  /// The valid range for a single focus preset, matching the Focus stepper in Settings.
  private static let focusPresetRange = 1...180

  /// The maximum number of presets a user can keep in ``focusPresets``.
  private static let maxFocusPresets = 5

  private let store: SettingsStore

  /// Creates settings backed by the standard `UserDefaults` suite.
  convenience init() {
    self.init(store: SettingsStore())
  }

  /// Creates settings backed by the provided ``SettingsStore``. Pass a store over a temporary suite in tests.
  init(store: SettingsStore) {
    self.store = store
    focusMinutes = store[SettingsStore.Keys.focusMinutes]
    focusPresets = store[SettingsStore.Keys.focusPresets]
    shortBreakMinutes = store[SettingsStore.Keys.shortBreakMinutes]
    longBreakMinutes = store[SettingsStore.Keys.longBreakMinutes]
    longBreakAfterSessions = store[SettingsStore.Keys.longBreakAfterSessions]
    soundEnabled = store[SettingsStore.Keys.soundEnabled]
    soundName = store[SettingsStore.Keys.soundName]
    notificationsEnabled = store[SettingsStore.Keys.notificationsEnabled]
    autoStartNextPhase = store[SettingsStore.Keys.autoStartNextPhase]
    sidebarVisible = store[SettingsStore.Keys.sidebarVisible]
    taskSortField = store[SettingsStore.Keys.taskSortField]
    taskSortDirection = store[SettingsStore.Keys.taskSortDirection]
    defaultWritableProviderID = store[SettingsStore.Keys.defaultWritableProviderID]
    collapsedSidebarSections = store[SettingsStore.Keys.collapsedSidebarSections]
  }

  // MARK: - Focus presets

  /// Normalizes a raw focus-preset list to the rules a valid ``focusPresets`` must satisfy
  /// (design doc 0009, D5): each value clamped to `1...180`, duplicates dropped, sorted
  /// ascending, and capped at 5 entries. An empty input falls back to the key's shipped
  /// default (`[15, 25, 45, 60]`).
  ///
  /// Pure and side-effect free, so it is the single, unit-tested source of truth for the
  /// rule — both ``setFocusPresets(_:)`` and its tests call this directly.
  static func normalizedPresets(_ raw: [Int]) -> [Int] {
    let clamped = raw.map { min(max($0, focusPresetRange.lowerBound), focusPresetRange.upperBound) }
    let deduplicated = Set(clamped).sorted()
    guard !deduplicated.isEmpty else { return SettingsStore.Keys.focusPresets.defaultValue }
    return Array(deduplicated.prefix(maxFocusPresets))
  }

  /// Normalizes `raw` and assigns it to ``focusPresets``.
  ///
  /// If the edit drops the value currently held by `focusMinutes`, `focusMinutes` re-snaps to
  /// the nearest remaining preset (an exact tie snaps to the lower value), so the two never
  /// disagree. Settings-editor add/remove actions should always route through this method
  /// rather than assigning `focusPresets` directly — it is the only path that can't produce an
  /// invalid list.
  func setFocusPresets(_ raw: [Int]) {
    let normalized = Self.normalizedPresets(raw)
    focusPresets = normalized
    guard !normalized.contains(focusMinutes) else { return }
    focusMinutes = Self.nearestPreset(to: focusMinutes, in: normalized)
  }

  /// The value in `presets` closest to `value`; an exact tie resolves to the lower value.
  private static func nearestPreset(to value: Int, in presets: [Int]) -> Int {
    presets.min { lhs, rhs in
      let lhsDistance = abs(lhs - value)
      let rhsDistance = abs(rhs - value)
      return lhsDistance == rhsDistance ? lhs < rhs : lhsDistance < rhsDistance
    } ?? value
  }
}
