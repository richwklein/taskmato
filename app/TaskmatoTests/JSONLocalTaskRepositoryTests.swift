//
//  JSONLocalTaskRepositoryTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

@Suite("JSONLocalTaskRepository")
struct JSONLocalTaskRepositoryTests {

  /// Creates a repository backed by a unique temporary file so tests are fully isolated.
  private func makeRepository() -> JSONLocalTaskRepository {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString + ".json")
    return JSONLocalTaskRepository(fileURL: url)
  }

  private func makeTask(title: String = "Task") -> LocalTask {
    var draft = TaskDraft()
    draft.title = title
    return LocalTask(from: draft)
  }

  @Test func loadAllReturnsEmptyStoreWhenFileIsMissing() async throws {
    let repository = makeRepository()
    let store = try await repository.loadAll()
    #expect(store.lists.isEmpty)
    #expect(store.tasks.isEmpty)
    #expect(store.defaultListID == nil)
  }

  @Test func loadAllThrowsWhenFileIsCorrupt() async throws {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString + ".json")
    try Data("not json".utf8).write(to: url, options: [])
    let repository = JSONLocalTaskRepository(fileURL: url)
    await #expect(throws: (any Error).self) {
      try await repository.loadAll()
    }
  }

  @Test func savedStoreRoundTripsThroughLoadAll() async throws {
    let repository = makeRepository()
    let list = LocalList(id: UUID(), name: "Work", createdAt: Date())
    let task = makeTask(title: "Write report")
    let store = LocalStore(lists: [list], tasks: [task], defaultListID: list.id.uuidString)
    try await repository.save(store)

    let loaded = try await repository.loadAll()
    #expect(loaded.lists.map(\.id) == [list.id])
    #expect(loaded.tasks.map(\.id) == [task.id])
    #expect(loaded.defaultListID == list.id.uuidString)
  }

  @Test func saveOverwritesPreviousContent() async throws {
    let repository = makeRepository()
    let firstList = LocalList(id: UUID(), name: "First", createdAt: Date())
    try await repository.save(
      LocalStore(lists: [firstList], tasks: [], defaultListID: firstList.id.uuidString))

    let secondList = LocalList(id: UUID(), name: "Second", createdAt: Date())
    try await repository.save(
      LocalStore(lists: [secondList], tasks: [], defaultListID: secondList.id.uuidString))

    let loaded = try await repository.loadAll()
    #expect(loaded.lists.map(\.id) == [secondList.id])
  }

  @Test func savedStorePersistsAcrossRepositoryInstances() async throws {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString + ".json")
    let first = JSONLocalTaskRepository(fileURL: url)
    let list = LocalList(id: UUID(), name: "Personal", createdAt: Date())
    try await first.save(LocalStore(lists: [list], tasks: [], defaultListID: list.id.uuidString))

    let second = JSONLocalTaskRepository(fileURL: url)
    let loaded = try await second.loadAll()
    #expect(loaded.lists.map(\.id) == [list.id])
  }
}
