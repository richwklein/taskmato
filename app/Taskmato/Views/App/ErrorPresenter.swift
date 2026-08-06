//
//  ErrorPresenter.swift
//  Taskmato
//

import Foundation
import Observation

/// How prominently a transient error is surfaced to the user.
enum ErrorSeverity {
  /// A recoverable problem that the user may want to know about but that did not block them.
  case warning
  /// An operation the user asked for that failed.
  case error
}

/// A short-lived, user-facing error with a title, optional detail, and severity.
struct TransientError: Identifiable, Equatable {
  /// Stable identity so the banner can animate between successive errors.
  let id = UUID()
  /// Short, human-readable summary of what failed.
  let title: String
  /// Optional supporting detail, typically an error's `localizedDescription`.
  let detail: String?
  /// How prominently the error is surfaced.
  let severity: ErrorSeverity

  init(title: String, detail: String? = nil, severity: ErrorSeverity = .error) {
    self.title = title
    self.detail = detail
    self.severity = severity
  }
}

/// Holds a queue of transient errors for the window-root banner, surfacing them one at a
/// time with an auto-dismiss timer and manual dismissal.
///
/// Errors are shown head-first: ``present(_:)`` enqueues, ``current`` is what the banner
/// renders, and each head auto-dismisses after `autoDismiss`. The `sleep` closure is
/// injectable so tests can drive the timer deterministically.
@Observable
@MainActor
final class ErrorPresenter {

  /// The pending errors, head-first; the banner renders ``current``.
  private(set) var queue: [TransientError] = []

  /// The error currently shown in the banner, or `nil` when the queue is empty.
  var current: TransientError? { queue.first }

  @ObservationIgnored private let autoDismiss: Duration
  @ObservationIgnored private let sleep: @Sendable (Duration) async throws -> Void
  /// The in-flight auto-dismiss timer for the current head; exposed for deterministic tests.
  @ObservationIgnored var dismissTask: Task<Void, Never>?

  /// - Parameters:
  ///   - autoDismiss: How long the current error stays before it auto-dismisses.
  ///   - sleep: The delay primitive; defaults to `Task.sleep`, overridable in tests.
  init(
    autoDismiss: Duration = .seconds(5),
    sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
  ) {
    self.autoDismiss = autoDismiss
    self.sleep = sleep
  }

  /// Enqueues an error, starting the auto-dismiss timer when it becomes the head.
  func present(_ error: TransientError) {
    queue.append(error)
    if queue.count == 1 { scheduleDismiss() }
  }

  /// Enqueues a caught error under `title`, using its `localizedDescription` as the detail.
  func present(title: String, error: Error, severity: ErrorSeverity = .error) {
    present(TransientError(title: title, detail: error.localizedDescription, severity: severity))
  }

  /// Runs a throwing operation, surfacing `title` with the error's description on failure.
  ///
  /// Keeps user-initiated provider mutations to a single `await` at the call site instead of a
  /// `do`/`catch`. Callers that need to react to success (e.g. clearing state only when a
  /// delete actually succeeded) can use the returned value; existing statement-form call sites
  /// are unaffected since the result is discardable.
  /// - Returns: `true` if `operation` completed without throwing, `false` if it threw (in which
  ///   case the error was already presented).
  @discardableResult
  func attempt(
    _ title: String, severity: ErrorSeverity = .error, _ operation: () async throws -> Void
  ) async -> Bool {
    do {
      try await operation()
      return true
    } catch {
      present(title: title, error: error, severity: severity)
      return false
    }
  }

  /// Dismisses the current error and surfaces the next queued one, if any.
  func dismiss() {
    guard !queue.isEmpty else { return }
    queue.removeFirst()
    dismissTask?.cancel()
    if !queue.isEmpty { scheduleDismiss() }
  }

  /// Starts (or restarts) the auto-dismiss timer for the current head.
  private func scheduleDismiss() {
    dismissTask?.cancel()
    let autoDismiss = self.autoDismiss
    let sleep = self.sleep
    dismissTask = Task { [weak self] in
      try? await sleep(autoDismiss)
      guard !Task.isCancelled, let self else { return }
      self.dismiss()
    }
  }
}
