//
//  SwiftDataLocalTaskRepository.swift
//  Taskmato
//

import Foundation
import SwiftData

/// A ``LocalTaskRepository`` backed by a SwiftData store.
///
/// `@ModelActor` isolates the non-`Sendable` `ModelContext` to this actor's executor.
/// The production store is `~/Library/Application Support/Taskmato/LocalTasks.store`.
@ModelActor
actor SwiftDataLocalTaskRepository: LocalTaskRepository {

  func loadAll() throws -> LocalStore {
    let lists = try modelContext.fetch(
      FetchDescriptor<LocalListEntity>(sortBy: [SortDescriptor(\.createdAt, order: .forward)]))
    let tasks = try modelContext.fetch(
      FetchDescriptor<LocalTaskEntity>(sortBy: [SortDescriptor(\.createdAt, order: .forward)]))
    let defaultListID = lists.first(where: \.isDefault)?.id.uuidString
    return LocalStore(
      lists: lists.map(LocalList.init(entity:)), tasks: tasks.map(LocalTask.init(entity:)),
      defaultListID: defaultListID)
  }

  func save(_ store: LocalStore) throws {
    try upsertLists(store.lists, defaultListID: store.defaultListID)
    try upsertTasks(store.tasks)
    try modelContext.save()
  }

  /// Diff-based upsert of `lists` against the current rows: mutates matching ids in place,
  /// inserts new ones, and deletes rows absent from `lists`.
  private func upsertLists(_ lists: [LocalList], defaultListID: String?) throws {
    let existing = try modelContext.fetch(FetchDescriptor<LocalListEntity>())
    var existingByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
    for list in lists {
      let isDefault = list.id.uuidString == defaultListID
      if let entity = existingByID.removeValue(forKey: list.id) {
        entity.update(from: list, isDefault: isDefault)
      } else {
        modelContext.insert(LocalListEntity(list: list, isDefault: isDefault))
      }
    }
    for orphan in existingByID.values { modelContext.delete(orphan) }
  }

  /// Diff-based upsert of `tasks` against the current rows: mutates matching ids in place,
  /// inserts new ones, and deletes rows absent from `tasks`.
  private func upsertTasks(_ tasks: [LocalTask]) throws {
    let existing = try modelContext.fetch(FetchDescriptor<LocalTaskEntity>())
    var existingByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
    for task in tasks {
      if let entity = existingByID.removeValue(forKey: task.id) {
        entity.update(from: task)
      } else {
        modelContext.insert(LocalTaskEntity(task: task))
      }
    }
    for orphan in existingByID.values { modelContext.delete(orphan) }
  }
}

extension SwiftDataLocalTaskRepository {

  /// File name of the production SwiftData store.
  static let storeFileName = "LocalTasks.store"

  /// The default production store URL, creating the containing directory if needed.
  static func defaultStoreURL() -> URL {
    let appSupport = FileManager.default.urls(
      for: .applicationSupportDirectory, in: .userDomainMask
    ).first!
    let dir = appSupport.appendingPathComponent("Taskmato", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir.appendingPathComponent(storeFileName)
  }

  /// Builds a persistent container at `url`.
  static func makeContainer(url: URL) throws -> ModelContainer {
    let configuration = ModelConfiguration(url: url)
    return try ModelContainer(
      for: LocalTaskEntity.self, LocalListEntity.self, configurations: configuration)
  }

  /// Builds an ephemeral in-memory container for tests and previews.
  static func makeInMemoryContainer() throws -> ModelContainer {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
      for: LocalTaskEntity.self, LocalListEntity.self, configurations: configuration)
  }

  /// A repository over a fresh in-memory container; the extractable fixture for tests and previews.
  static func makeInMemory() throws -> SwiftDataLocalTaskRepository {
    SwiftDataLocalTaskRepository(modelContainer: try makeInMemoryContainer())
  }
}
