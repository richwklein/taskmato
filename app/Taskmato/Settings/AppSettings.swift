//
//  AppSettings.swift
//  Taskmato
//

import Observation
import Foundation

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
        focusMinutes           = defaults.integer(forKey: Keys.focusMinutes).nonZero ?? 25
        shortBreakMinutes      = defaults.integer(forKey: Keys.shortBreakMinutes).nonZero ?? 5
        longBreakMinutes       = defaults.integer(forKey: Keys.longBreakMinutes).nonZero ?? 15
        longBreakAfterSessions = defaults.integer(forKey: Keys.longBreakAfterSessions).nonZero ?? 4
        soundEnabled           = defaults.object(forKey: Keys.soundEnabled) as? Bool ?? true
        notificationsEnabled   = defaults.object(forKey: Keys.notificationsEnabled) as? Bool ?? true
        autoStartNextPhase     = defaults.object(forKey: Keys.autoStartNextPhase) as? Bool ?? false
    }

    private enum Keys {
        static let focusMinutes           = "focusMinutes"
        static let shortBreakMinutes      = "shortBreakMinutes"
        static let longBreakMinutes       = "longBreakMinutes"
        static let longBreakAfterSessions = "longBreakAfterSessions"
        static let soundEnabled            = "soundEnabled"
        static let notificationsEnabled   = "notificationsEnabled"
        static let autoStartNextPhase     = "autoStartNextPhase"
    }
}

private extension Int {
    /// Returns `self` if greater than zero, otherwise `nil`.
    var nonZero: Int? { self > 0 ? self : nil }
}
