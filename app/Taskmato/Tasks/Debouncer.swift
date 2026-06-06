//
//  Debouncer.swift
//  Taskmato
//

import Foundation

/// Coalesces rapid calls by cancelling any pending work before scheduling a new run.
///
/// Implicitly `@MainActor` (via `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`), so it is safe
/// to call synchronously from either provider's change-event handler without additional
/// actor-hop boilerplate.
final class Debouncer {

  private let interval: Duration
  private var pending: Task<Void, Never>?

  /// Creates a debouncer with the given coalescing interval; defaults to 250 ms.
  init(interval: Duration = .milliseconds(250)) {
    self.interval = interval
  }

  /// Cancels any pending action and schedules `action` to run after the interval.
  func schedule(_ action: @escaping () async -> Void) {
    pending?.cancel()
    let interval = self.interval
    pending = Task { [action, interval] in
      try? await Task.sleep(for: interval)
      guard !Task.isCancelled else { return }
      await action()
    }
  }

  /// Cancels any pending action without running it.
  func cancel() {
    pending?.cancel()
    pending = nil
  }
}
