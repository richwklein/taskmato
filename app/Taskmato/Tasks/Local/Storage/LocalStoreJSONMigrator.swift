//
//  LocalStoreJSONMigrator.swift
//  Taskmato
//

import Foundation
import SwiftData
import os

/// One-shot migration of the legacy `local-tasks.json` store into a SwiftData
/// ``SwiftDataLocalTaskRepository`` container.
///
/// Runs synchronously during composition, before ``LocalProvider`` is constructed, using a
/// fresh `ModelContext` over the already-open container — never through the `@ModelActor`, so
/// no `await` is needed and the provider can never race an in-flight import. It never throws:
/// data-shaped failures (missing file, corrupt JSON) are logged and handled internally so they
/// never reach the composition-root `fatalError`, which is reserved for container-open
/// failures only.
enum LocalStoreJSONMigrator {

  private static let logger = Logger(subsystem: "com.taskmato", category: "LocalStoreJSONMigrator")

  /// Imports `jsonURL` into `container` if this is the first launch under SwiftData, then
  /// archives the JSON file so the import never repeats.
  ///
  /// No-op if `jsonURL` does not exist. If `container` is already populated, the import is
  /// skipped but the stale JSON is still archived (idempotency: presence of the JSON file is
  /// the sole "first launch" signal). On a decode or write failure, the store is left empty and
  /// `jsonURL` is left in place, unarchived, for manual recovery — a subsequent
  /// ``LocalProvider`` load still succeeds by creating a fresh Default list.
  /// - Parameters:
  ///   - jsonURL: The legacy JSON store file to import.
  ///   - container: The already-open SwiftData container to import into.
  static func migrateIfNeeded(jsonURL: URL, into container: ModelContainer) {
    guard FileManager.default.fileExists(atPath: jsonURL.path) else { return }

    let context = ModelContext(container)
    let alreadyPopulated: Int
    do {
      alreadyPopulated = try context.fetchCount(FetchDescriptor<LocalListEntity>())
    } catch {
      logger.error(
        "Failed to check existing store before migration: \(error.localizedDescription, privacy: .public)"
      )
      return
    }
    if alreadyPopulated > 0 {
      archive(jsonURL)
      return
    }

    do {
      let data = try Data(contentsOf: jsonURL)
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      let store = try decoder.decode(LocalStore.self, from: data)
      for (index, list) in store.lists.enumerated() {
        let isDefault = list.id.uuidString == store.defaultListID
        // Legacy lists carry no createdAt (decoded as .distantPast) — synthesize ascending
        // timestamps anchored well before any real Date() so migrated order is preserved and
        // new in-app lists always sort after the migrated set.
        let synthesizedCreatedAt = Date(timeIntervalSince1970: Double(index))
        context.insert(
          LocalListEntity(
            id: list.id, name: list.name, createdAt: synthesizedCreatedAt, isDefault: isDefault))
      }
      for task in store.tasks {
        context.insert(LocalTaskEntity(task: task))
      }
      try context.save()
    } catch {
      logger.error(
        "Failed to migrate local task store from JSON: \(error.localizedDescription, privacy: .public)"
      )
      return
    }

    archive(jsonURL)
  }

  /// Renames `jsonURL` to `.archived`, removing any stale archive from a previous run first.
  private static func archive(_ jsonURL: URL) {
    let archivedURL = jsonURL.appendingPathExtension("archived")
    let fileManager = FileManager.default
    if fileManager.fileExists(atPath: archivedURL.path) {
      try? fileManager.removeItem(at: archivedURL)
    }
    do {
      try fileManager.moveItem(at: jsonURL, to: archivedURL)
    } catch {
      logger.error(
        "Failed to archive migrated local-tasks.json: \(error.localizedDescription, privacy: .public)"
      )
    }
  }
}
