//
//  MulticastAsyncStream.swift
//  Taskmato
//

import Foundation

/// Owns independent `AsyncStream` subscriptions and broadcasts each value to every subscriber.
@MainActor
final class MulticastAsyncStream<Element: Sendable> {

  private var continuations: [UUID: AsyncStream<Element>.Continuation] = [:]

  /// Called after the final consumer terminates.
  var onEmpty: (() -> Void)?

  /// Creates a stream subscription that is removed when its consumer terminates.
  func subscribe() -> AsyncStream<Element> {
    let id = UUID()
    let (stream, continuation) = AsyncStream<Element>.makeStream()
    continuations[id] = continuation
    continuation.onTermination = { [weak self] _ in
      Task { @MainActor [weak self] in
        self?.remove(id)
      }
    }
    return stream
  }

  /// Sends `value` to all current subscribers.
  func yield(_ value: Element) {
    for continuation in continuations.values {
      continuation.yield(value)
    }
  }

  /// Finishes all subscriptions and removes them.
  func finish() {
    let subscribers = Array(continuations.values)
    continuations.removeAll()
    for continuation in subscribers {
      continuation.finish()
    }
  }

  /// Runs `body` after a subscriber terminates, allowing the owner to stop its source watcher.
  var isEmpty: Bool { continuations.isEmpty }

  private func remove(_ id: UUID) {
    continuations.removeValue(forKey: id)
    if continuations.isEmpty { onEmpty?() }
  }
}
