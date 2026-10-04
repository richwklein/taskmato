//
//  TaskTemporalObserver.swift
//  Taskmato
//

import AppKit
import Foundation
import Observation

/// Bumps ``token`` when the day, time zone, or locale changes so relative due-date labels
/// re-evaluate; see ``StatsTemporalObserver`` for the statistics counterpart.
@MainActor
@Observable
final class TaskTemporalObserver {

  /// Changes whenever a clock-relevant notification arrives.
  private(set) var token = 0

  @ObservationIgnored private var tokens: [NSObjectProtocol] = []

  init() {
    let center = NotificationCenter.default
    let names = [
      NSApplication.didBecomeActiveNotification,
      NSLocale.currentLocaleDidChangeNotification,
      NSNotification.Name.NSSystemTimeZoneDidChange,
      NSNotification.Name.NSCalendarDayChanged,
    ]
    tokens = names.map { name in
      center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
        Task { @MainActor in self?.token += 1 }
      }
    }
  }

  isolated deinit {
    for token in tokens {
      NotificationCenter.default.removeObserver(token)
    }
  }
}
