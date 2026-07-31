//
//  SettingsStore.swift
//  Taskmato
//

import Foundation

/// A typed, defaulted key into ``SettingsStore``.
///
/// Pairs a persisted `UserDefaults` key name with the value returned when the key is absent.
struct SettingsKey<Value> {

  /// The `UserDefaults` key string, preserved verbatim across releases to avoid data migration.
  let name: String

  /// The value returned when no stored value exists for ``name``.
  let defaultValue: Value

  /// - Parameters:
  ///   - name: The `UserDefaults` key string.
  ///   - defaultValue: The value returned when the key is absent.
  init(_ name: String, default defaultValue: Value) {
    self.name = name
    self.defaultValue = defaultValue
  }
}

/// The single typed gateway to `UserDefaults` — the one place the app reads and writes settings.
///
/// Every persisted key is enumerated in ``Keys``. Scalar and enum values use typed ``SettingsKey``
/// subscripts; `Codable` values round-trip through ``value(forKey:as:)`` / ``setValue(_:forKey:)``
/// and raw `Data` (e.g. a security-scoped bookmark) through ``data(forKey:)`` / ``setData(_:forKey:)``.
/// Key strings and value encodings match the pre-consolidation layout, so existing user settings
/// survive an upgrade.
final class SettingsStore {

  private let defaults: UserDefaults

  /// - Parameter defaults: Backing store. Pass a temporary suite in tests.
  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  // MARK: - Scalar & enum keys

  /// Reads or writes an integer setting, returning the key's default when absent.
  subscript(key: SettingsKey<Int>) -> Int {
    get { (defaults.object(forKey: key.name) as? Int) ?? key.defaultValue }
    set { defaults.set(newValue, forKey: key.name) }
  }

  /// Reads or writes a boolean setting, returning the key's default when absent.
  subscript(key: SettingsKey<Bool>) -> Bool {
    get { (defaults.object(forKey: key.name) as? Bool) ?? key.defaultValue }
    set { defaults.set(newValue, forKey: key.name) }
  }

  /// Reads or writes a string setting, returning the key's default when absent.
  subscript(key: SettingsKey<String>) -> String {
    get { defaults.string(forKey: key.name) ?? key.defaultValue }
    set { defaults.set(newValue, forKey: key.name) }
  }

  /// Reads or writes an optional string setting, removing the key when set to `nil`.
  subscript(key: SettingsKey<String?>) -> String? {
    get { defaults.string(forKey: key.name) ?? key.defaultValue }
    set {
      if let newValue {
        defaults.set(newValue, forKey: key.name)
      } else {
        defaults.removeObject(forKey: key.name)
      }
    }
  }

  /// Reads or writes a string-array setting, returning the key's default when absent.
  subscript(key: SettingsKey<[String]>) -> [String] {
    get { defaults.stringArray(forKey: key.name) ?? key.defaultValue }
    set { defaults.set(newValue, forKey: key.name) }
  }

  /// Reads or writes a string set stored as an array, returning the key's default when absent.
  subscript(key: SettingsKey<Set<String>>) -> Set<String> {
    get {
      guard let stored = defaults.stringArray(forKey: key.name) else { return key.defaultValue }
      return Set(stored)
    }
    set { defaults.set(Array(newValue), forKey: key.name) }
  }

  /// Reads or writes a `String`-backed `RawRepresentable` (e.g. an enum), stored as its raw value.
  subscript<Value: RawRepresentable>(key: SettingsKey<Value>) -> Value
  where Value.RawValue == String {
    get { defaults.string(forKey: key.name).flatMap { Value(rawValue: $0) } ?? key.defaultValue }
    set { defaults.set(newValue.rawValue, forKey: key.name) }
  }

  /// Reads or writes an optional `String`-backed `RawRepresentable`, removing the key when `nil`.
  subscript<Value: RawRepresentable>(key: SettingsKey<Value?>) -> Value?
  where Value.RawValue == String {
    get { defaults.string(forKey: key.name).flatMap { Value(rawValue: $0) } ?? key.defaultValue }
    set {
      if let newValue {
        defaults.set(newValue.rawValue, forKey: key.name)
      } else {
        defaults.removeObject(forKey: key.name)
      }
    }
  }

  /// Reads or writes a set of `String`-backed `RawRepresentable` values, stored as a string array.
  subscript<Value: RawRepresentable>(key: SettingsKey<Set<Value>>) -> Set<Value>
  where Value.RawValue == String {
    get {
      guard let stored = defaults.stringArray(forKey: key.name) else { return key.defaultValue }
      return Set(stored.compactMap(Value.init(rawValue:)))
    }
    set { defaults.set(newValue.map(\.rawValue), forKey: key.name) }
  }

  // MARK: - Codable & Data values

  /// Decodes a JSON-encoded `Codable` value for `key`, or `nil` when absent or undecodable.
  /// - Parameters:
  ///   - key: The persisted key string, from ``Keys``.
  ///   - type: The value type to decode.
  func value<Value: Decodable>(forKey key: String, as type: Value.Type = Value.self) -> Value? {
    guard let data = defaults.data(forKey: key) else { return nil }
    return try? JSONDecoder().decode(Value.self, from: data)
  }

  /// JSON-encodes and stores `value` for `key`, removing the key when `value` is `nil` or fails to encode.
  func setValue<Value: Encodable>(_ value: Value?, forKey key: String) {
    guard let value, let data = try? JSONEncoder().encode(value) else {
      defaults.removeObject(forKey: key)
      return
    }
    defaults.set(data, forKey: key)
  }

  /// Reads raw `Data` for `key` (e.g. a security-scoped bookmark), or `nil` when absent.
  func data(forKey key: String) -> Data? {
    defaults.data(forKey: key)
  }

  /// Writes raw `Data` for `key`, removing the key when `data` is `nil`.
  func setData(_ data: Data?, forKey key: String) {
    if let data {
      defaults.set(data, forKey: key)
    } else {
      defaults.removeObject(forKey: key)
    }
  }
}

extension SettingsStore {

  /// Every persisted `UserDefaults` key the app uses, named in one place.
  ///
  /// Scalar and enum keys are typed ``SettingsKey`` values carrying their default; `Codable`
  /// and `Data` keys are plain strings used with ``SettingsStore/value(forKey:as:)`` and
  /// ``SettingsStore/data(forKey:)``.
  enum Keys {

    // MARK: Timer durations & session cadence

    static let focusMinutes = SettingsKey("focusMinutes", default: 25)
    static let shortBreakMinutes = SettingsKey("shortBreakMinutes", default: 5)
    static let longBreakMinutes = SettingsKey("longBreakMinutes", default: 15)
    static let longBreakAfterSessions = SettingsKey("longBreakAfterSessions", default: 4)

    // MARK: Alerts

    static let soundEnabled = SettingsKey("soundEnabled", default: true)
    static let soundName = SettingsKey("soundName", default: "Hero")
    static let notificationsEnabled = SettingsKey("notificationsEnabled", default: true)
    static let autoStartNextPhase = SettingsKey("autoStartNextPhase", default: false)

    // MARK: Task views & sidebar

    static let taskPickerLayout = SettingsKey("taskPickerLayout", default: TaskPickerLayout.grid)
    static let sidebarVisible = SettingsKey("taskRegistry.sidebarVisible", default: true)
    static let taskSortField = SettingsKey("taskSort.field", default: TaskSortField.dueDate)
    static let taskSortDirection = SettingsKey(
      "taskSort.direction", default: TaskSortDirection.ascending)
    static let defaultWritableProviderID = SettingsKey<ProviderID?>(
      "tasks.defaultWritableProviderID", default: nil)
    static let collapsedSidebarSections = SettingsKey(
      "sidebar.collapsedSections", default: Set<String>())

    // MARK: Provider registry

    static let enabledProviderIDs = SettingsKey(
      "taskRegistry.enabledProviderIDs", default: Set<ProviderID>())

    // MARK: Obsidian provider

    static let obsidianFilePatterns = SettingsKey("obsidian.filePatterns", default: ["**/*.md"])
    static let obsidianVaultBookmark = "obsidian.vaultBookmark"

    // MARK: Reminders provider

    static let remindersListPatterns = SettingsKey("reminders.listPatterns", default: [String]())

    // MARK: Codable navigation & selection blobs

    static let sidebarSelection = "taskRegistry.selection"
    static let activeTask = "taskSelection.activeTask"
    static let recentsByProvider = "taskSelection.recentsByProvider"
    static let shellDestination = "shell.destination"
  }
}
