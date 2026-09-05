//
//  StatsTemporalObserver.swift
//  Taskmato
//

import AppKit
import Foundation

/// Owns app-lifetime notifications that refresh calendar-dependent statistics.
@MainActor
final class StatsTemporalObserver {
  private var tokens: [NSObjectProtocol] = []

  /// Observes activation, locale, time-zone, and day-rollover changes on behalf of `stats`.
  init(stats: StatsViewModel) {
    let center = NotificationCenter.default
    let names = [
      NSApplication.didBecomeActiveNotification,
      NSLocale.currentLocaleDidChangeNotification,
      NSNotification.Name.NSSystemTimeZoneDidChange,
      NSNotification.Name.NSCalendarDayChanged,
    ]
    tokens = names.map { name in
      center.addObserver(forName: name, object: nil, queue: .main) { [weak stats] _ in
        Task { @MainActor in stats?.refreshTemporalContext() }
      }
    }
  }

  isolated deinit {
    for token in tokens {
      NotificationCenter.default.removeObserver(token)
    }
  }
}
