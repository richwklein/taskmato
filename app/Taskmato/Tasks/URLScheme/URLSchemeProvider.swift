//
//  URLSchemeProvider.swift
//  Taskmato
//

import Foundation

/// A task provider that surfaces ad-hoc tasks created via the `taskmato://` URL scheme.
///
/// Tasks are held in memory and the most recent `maxRecents` are persisted to
/// JSON in Application Support so they survive relaunch.
@MainActor
final class URLSchemeProvider: TaskProvider {

  /// The stable provider ID used in `TaskRef.providerID` for all CLI-sourced tasks.
  static let providerID = "cli"

  /// Maximum number of ad-hoc tasks retained in the recents list.
  static let maxRecents = 10

  var id: String { Self.providerID }
  let displayName = "CLI"
  let entitlement: ProviderEntitlement = .free

  private var items: [TaskItem] = []
  private let persistenceURL: URL

  /// - Parameter persistenceURL: Override the JSON storage location. Defaults to
  ///   `~/Library/Application Support/Taskmato/cli-tasks.json`. Override in tests.
  init(persistenceURL: URL? = nil) {
    if let override = persistenceURL {
      self.persistenceURL = override
    } else {
      let appSupport = FileManager.default.urls(
        for: .applicationSupportDirectory,
        in: .userDomainMask
      ).first!
      let dir = appSupport.appendingPathComponent("Taskmato", isDirectory: true)
      self.persistenceURL = dir.appendingPathComponent("cli-tasks.json")
    }
    load()
  }

  // MARK: - TaskProvider

  nonisolated func authorize() async throws {}

  func lists() async throws -> [TaskList] { [] }

  func tasks(in list: TaskList?) async throws -> [TaskItem] { items }

  func observe() -> AsyncStream<[TaskItem]>? { nil }

  // MARK: - Mutation

  /// Prepends a task to the recents list, deduplicating by native ID and capping at `maxRecents`.
  func add(_ task: TaskItem) {
    items.removeAll { $0.id.nativeID == task.id.nativeID }
    items.insert(task, at: 0)
    if items.count > Self.maxRecents {
      items = Array(items.prefix(Self.maxRecents))
    }
    persist()
  }

  // MARK: - Persistence

  private func persist() {
    let dir = persistenceURL.deletingLastPathComponent()
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    if let data = try? JSONEncoder().encode(items) {
      try? data.write(to: persistenceURL)
    }
  }

  private func load() {
    guard let data = try? Data(contentsOf: persistenceURL) else { return }
    items = (try? JSONDecoder().decode([TaskItem].self, from: data)) ?? []
  }
}
