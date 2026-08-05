//
//  LocalStoreJSONMigratorTests.swift
//  TaskmatoTests
//

import Foundation
import SwiftData
import Testing

@testable import Taskmato

@Suite("LocalStoreJSONMigrator")
struct LocalStoreJSONMigratorTests {

  /// A unique JSON file path under a real temp directory, so the archive rename genuinely
  /// exercises the filesystem.
  private func makeJSONURL() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
  }

  private func makeTask(title: String = "Task") -> LocalTask {
    var draft = TaskDraft()
    draft.title = title
    return LocalTask(from: draft)
  }

  @Test func happyPathImportsAndArchives() async throws {
    let jsonURL = makeJSONURL()
    let firstList = LocalList(id: UUID(), name: "First", createdAt: Date())
    let secondList = LocalList(id: UUID(), name: "Second", createdAt: Date())
    let task = makeTask(title: "Write report")
    let store = LocalStore(
      lists: [firstList, secondList], tasks: [task], defaultListID: secondList.id.uuidString)
    try await JSONLocalTaskRepository(fileURL: jsonURL).save(store)

    let container = try SwiftDataLocalTaskRepository.makeInMemoryContainer()
    LocalStoreJSONMigrator.migrateIfNeeded(jsonURL: jsonURL, into: container)

    let repository = SwiftDataLocalTaskRepository(modelContainer: container)
    let loaded = try await repository.loadAll()
    #expect(loaded.lists.map(\.id) == [firstList.id, secondList.id])
    #expect(loaded.tasks.map(\.id) == [task.id])
    #expect(loaded.defaultListID == secondList.id.uuidString)

    let archivedURL = jsonURL.appendingPathExtension("archived")
    #expect(FileManager.default.fileExists(atPath: archivedURL.path))
    #expect(!FileManager.default.fileExists(atPath: jsonURL.path))
  }

  @Test func emptyJSONStoreArchivesWithEmptyResult() async throws {
    let jsonURL = makeJSONURL()
    let store = LocalStore(lists: [], tasks: [], defaultListID: nil)
    try await JSONLocalTaskRepository(fileURL: jsonURL).save(store)

    let container = try SwiftDataLocalTaskRepository.makeInMemoryContainer()
    LocalStoreJSONMigrator.migrateIfNeeded(jsonURL: jsonURL, into: container)

    let repository = SwiftDataLocalTaskRepository(modelContainer: container)
    let loaded = try await repository.loadAll()
    #expect(loaded.lists.isEmpty)
    #expect(loaded.tasks.isEmpty)

    let archivedURL = jsonURL.appendingPathExtension("archived")
    #expect(FileManager.default.fileExists(atPath: archivedURL.path))
  }

  @Test func missingJSONIsANoOp() async throws {
    let jsonURL = makeJSONURL()
    let container = try SwiftDataLocalTaskRepository.makeInMemoryContainer()
    LocalStoreJSONMigrator.migrateIfNeeded(jsonURL: jsonURL, into: container)

    let repository = SwiftDataLocalTaskRepository(modelContainer: container)
    let loaded = try await repository.loadAll()
    #expect(loaded.lists.isEmpty)
    #expect(loaded.tasks.isEmpty)

    let archivedURL = jsonURL.appendingPathExtension("archived")
    #expect(!FileManager.default.fileExists(atPath: archivedURL.path))
  }

  @Test func alreadyPopulatedStoreSkipsImportButStillArchives() async throws {
    let jsonURL = makeJSONURL()
    let jsonList = LocalList(id: UUID(), name: "FromJSON", createdAt: Date())
    let store = LocalStore(lists: [jsonList], tasks: [], defaultListID: jsonList.id.uuidString)
    try await JSONLocalTaskRepository(fileURL: jsonURL).save(store)

    let container = try SwiftDataLocalTaskRepository.makeInMemoryContainer()
    let existingList = LocalList(id: UUID(), name: "AlreadyThere", createdAt: Date())
    let seedRepository = SwiftDataLocalTaskRepository(modelContainer: container)
    try await seedRepository.save(
      LocalStore(lists: [existingList], tasks: [], defaultListID: existingList.id.uuidString))

    LocalStoreJSONMigrator.migrateIfNeeded(jsonURL: jsonURL, into: container)

    let loaded = try await seedRepository.loadAll()
    #expect(loaded.lists.map(\.id) == [existingList.id])

    let archivedURL = jsonURL.appendingPathExtension("archived")
    #expect(FileManager.default.fileExists(atPath: archivedURL.path))
    #expect(!FileManager.default.fileExists(atPath: jsonURL.path))
  }

  @Test func corruptJSONLeavesStoreEmptyAndFileUnarchived() async throws {
    let jsonURL = makeJSONURL()
    try Data("not valid json".utf8).write(to: jsonURL, options: [])

    let container = try SwiftDataLocalTaskRepository.makeInMemoryContainer()
    LocalStoreJSONMigrator.migrateIfNeeded(jsonURL: jsonURL, into: container)

    let repository = SwiftDataLocalTaskRepository(modelContainer: container)
    let loaded = try await repository.loadAll()
    #expect(loaded.lists.isEmpty)
    #expect(loaded.tasks.isEmpty)

    let archivedURL = jsonURL.appendingPathExtension("archived")
    #expect(!FileManager.default.fileExists(atPath: archivedURL.path))
    #expect(FileManager.default.fileExists(atPath: jsonURL.path))
  }
}
