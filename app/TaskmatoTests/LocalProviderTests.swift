//
//  LocalProviderTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

// MARK: - Helpers for orphan-reassignment test

/// A parallel Codable container used to write a raw JSON fixture with nil listIDs,
/// simulating pre-list-enforcement data for the orphan-reassignment test.
private struct RawLocalStore: Codable {
  struct RawTask: Codable {
    let id: UUID
    var title: String
    var notes: String?
    var priority: TaskPriority
    var dueDate: Date?
    var scheduledDate: Date?
    var startDate: Date?
    var listID: UUID?
    var isCompleted: Bool
    var completedAt: Date?
    let createdAt: Date
  }
  struct RawList: Codable {
    let id: UUID
    var name: String
  }
  var lists: [RawList]
  var tasks: [RawTask]
}

// MARK: - Tests

@Suite("LocalProvider")
@MainActor
struct LocalProviderTests {

  /// Creates a provider backed by a unique temporary file so tests are fully isolated.
  private func makeProvider() -> LocalProvider {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString + ".json")
    return LocalProvider(fileURL: url)
  }

  // MARK: - Default list

  @Test func createsDefaultListOnFirstLoad() {
    let provider = makeProvider()
    #expect(provider.taskLists.count == 1)
    #expect(provider.taskLists[0].name == "Default")
  }

  @Test func defaultListIDIsSetOnFirstLoad() {
    let provider = makeProvider()
    #expect(provider.defaultListID == provider.taskLists[0].id.uuidString)
  }

  @Test func defaultListIDPersistsAcrossReload() {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString + ".json")
    let first = LocalProvider(fileURL: url)
    let storedID = first.defaultListID!

    let second = LocalProvider(fileURL: url)
    #expect(second.defaultListID == storedID)
  }

  @Test func setDefaultListChangesDefault() async throws {
    let provider = makeProvider()
    try await provider.createList(name: "Work")
    let workID = provider.taskLists[1].id.uuidString
    try await provider.setDefaultList(workID)
    #expect(provider.defaultListID == workID)
  }

  @Test func setDefaultListThrowsForUnknownID() async {
    let provider = makeProvider()
    await #expect(throws: LocalProviderError.self) {
      try await provider.setDefaultList(UUID().uuidString)
    }
  }

  @Test func doesNotDuplicateDefaultListOnReload() {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString + ".json")
    let first = LocalProvider(fileURL: url)
    let defaultID = first.taskLists[0].id

    let second = LocalProvider(fileURL: url)
    #expect(second.taskLists.count == 1)
    #expect(second.taskLists[0].id == defaultID)
  }

  @Test func orphanedTasksAssignedToDefaultListOnLoad() async throws {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString + ".json")

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601

    let rawList = RawLocalStore.RawList(id: UUID(), name: "Existing")
    let rawTask = RawLocalStore.RawTask(
      id: UUID(),
      title: "Orphan",
      priority: .none,
      isCompleted: false,
      createdAt: Date()
    )
    let raw = RawLocalStore(lists: [rawList], tasks: [rawTask])
    let data = try encoder.encode(raw)
    try data.write(to: url, options: [])

    let provider = LocalProvider(fileURL: url)
    let tasks = try await provider.tasks(in: nil)
    #expect(tasks.count == 1)
    #expect(tasks[0].title == "Orphan")
    #expect(tasks[0].list?.id == rawList.id.uuidString)
  }

  // MARK: - Task CRUD

  @Test func addTaskAppearsInActiveTasks() async throws {
    let provider = makeProvider()
    var draft = TaskDraft()
    draft.title = "My task"
    try await provider.addTask(draft)
    let tasks = try await provider.tasks(in: nil)
    #expect(tasks.count == 1)
    #expect(tasks[0].title == "My task")
  }

  @Test func activeTaskCarriesCreatedAt() async throws {
    let provider = makeProvider()
    let before = Date()
    var draft = TaskDraft()
    draft.title = "Timestamped"
    try await provider.addTask(draft)
    let after = Date()
    let tasks = try await provider.tasks(in: nil)
    let createdAt = try #require(tasks.first?.createdAt)
    #expect(createdAt >= before)
    #expect(createdAt <= after)
  }

  @Test func addTaskUsesDefaultListWhenNoDraftListID() async throws {
    let provider = makeProvider()
    let defaultID = provider.defaultListID!
    var draft = TaskDraft()
    draft.title = "Orphan"
    try await provider.addTask(draft)

    let list = TaskList(id: defaultID, providerID: LocalProvider.providerID, name: "Default")
    let tasks = try await provider.tasks(in: list)
    #expect(tasks.map(\.title).contains("Orphan"))
  }

  @Test func addTaskPersistsAcrossReload() async throws {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString + ".json")
    let first = LocalProvider(fileURL: url)
    var draft = TaskDraft()
    draft.title = "Persisted"
    try await first.addTask(draft)

    let second = LocalProvider(fileURL: url)
    let tasks = try await second.tasks(in: nil)
    #expect(tasks.map(\.title).contains("Persisted"))
  }

  @Test func completeRemovesTaskFromActiveTasks() async throws {
    let provider = makeProvider()
    var draft = TaskDraft()
    draft.title = "To complete"
    try await provider.addTask(draft)
    let ref = try await provider.tasks(in: nil)[0].id
    try await provider.complete(ref)
    let remaining = try await provider.tasks(in: nil)
    #expect(remaining.isEmpty)
  }

  @Test func completeAppearsInCompletedTasks() async throws {
    let provider = makeProvider()
    var draft = TaskDraft()
    draft.title = "Done"
    try await provider.addTask(draft)
    let ref = try await provider.tasks(in: nil)[0].id
    try await provider.complete(ref)
    let completed = try await provider.completedTasks()
    #expect(completed.count == 1)
    #expect(completed[0].title == "Done")
  }

  @Test func completedTasksItemsCarryCompletedAt() async throws {
    let provider = makeProvider()
    var draft = TaskDraft()
    draft.title = "With Date"
    try await provider.addTask(draft)
    let ref = try await provider.tasks(in: nil)[0].id
    let before = Date()
    try await provider.complete(ref)
    let after = Date()
    let completed = try await provider.completedTasks()
    #expect(completed.count == 1)
    let stamp = try #require(completed[0].completedAt)
    #expect(stamp >= before)
    #expect(stamp <= after)
  }

  @Test func reopenRestoresTaskToActive() async throws {
    let provider = makeProvider()
    var draft = TaskDraft()
    draft.title = "Reopen me"
    try await provider.addTask(draft)
    let ref = try await provider.tasks(in: nil)[0].id
    try await provider.complete(ref)
    try await provider.reopen(ref)
    let active = try await provider.tasks(in: nil)
    #expect(active.count == 1)
    let completed = try await provider.completedTasks()
    #expect(completed.isEmpty)
  }

  @Test func completedTasksExcludesActiveTasks() async throws {
    let provider = makeProvider()
    for title in ["A", "B", "C"] {
      var draft = TaskDraft()
      draft.title = title
      try await provider.addTask(draft)
    }
    let active = try await provider.tasks(in: nil)
    try await provider.complete(active[0].id)
    try await provider.complete(active[1].id)
    let completed = try await provider.completedTasks()
    #expect(completed.count == 2)
    let remaining = try await provider.tasks(in: nil)
    #expect(remaining.count == 1)
  }

  @Test func deleteTaskRemovesPermanently() async throws {
    let provider = makeProvider()
    var draft = TaskDraft()
    draft.title = "Delete me"
    try await provider.addTask(draft)
    let ref = try await provider.tasks(in: nil)[0].id
    try await provider.deleteTask(ref)
    #expect(try await provider.tasks(in: nil).isEmpty)
    #expect(try await provider.completedTasks().isEmpty)
  }

  @Test func writableProviderDeleteTaskRemovesCompletedItem() async throws {
    let provider = makeProvider()
    var draft = TaskDraft()
    draft.title = "Completed and deleted"
    try await provider.addTask(draft)
    let ref = try await provider.tasks(in: nil)[0].id
    try await provider.complete(ref)
    let writable: any WritableTaskProvider = provider
    try await writable.deleteTask(ref)
    #expect(try await provider.completedTasks().isEmpty)
  }

  @Test func updateTaskAppliesNewTitle() async throws {
    let provider = makeProvider()
    var draft = TaskDraft()
    draft.title = "Original"
    try await provider.addTask(draft)
    let ref = try await provider.tasks(in: nil)[0].id
    var updated = TaskDraft()
    updated.title = "Updated"
    try await provider.updateTask(ref, draft: updated)
    let tasks = try await provider.tasks(in: nil)
    #expect(tasks[0].title == "Updated")
  }

  @Test func addTaskHasMarkdownFormat() async throws {
    let provider = makeProvider()
    var draft = TaskDraft()
    draft.title = "Markdown task"
    try await provider.addTask(draft)
    let tasks = try await provider.tasks(in: nil)
    #expect(tasks[0].format == .markdown)
  }

  @Test func existingTaskWithoutFormatFieldDecodesAsMarkdown() async throws {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString + ".json")

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601

    let rawList = RawLocalStore.RawList(id: UUID(), name: "Default")
    let rawTask = RawLocalStore.RawTask(
      id: UUID(),
      title: "Legacy task",
      priority: .none,
      isCompleted: false,
      createdAt: Date()
    )
    let raw = RawLocalStore(lists: [rawList], tasks: [rawTask])
    let data = try encoder.encode(raw)
    try data.write(to: url, options: [])

    let provider = LocalProvider(fileURL: url)
    let tasks = try await provider.tasks(in: nil)
    #expect(tasks.count == 1)
    #expect(tasks[0].format == .markdown)
  }

  @Test func activeTaskCountExcludesCompleted() async throws {
    let provider = makeProvider()
    var draft = TaskDraft()
    draft.title = "Count me"
    try await provider.addTask(draft)
    #expect(provider.activeTaskCount == 1)
    let ref = try await provider.tasks(in: nil)[0].id
    try await provider.complete(ref)
    #expect(provider.activeTaskCount == 0)
  }

  // MARK: - List CRUD

  @Test func createListAddsToProvider() async throws {
    let provider = makeProvider()
    try await provider.createList(name: "Work")
    #expect(provider.taskLists.count == 2)
    #expect(provider.taskLists.map(\.name).contains("Work"))
  }

  @Test func renameListUpdatesName() async throws {
    let provider = makeProvider()
    let listID = provider.taskLists[0].id.uuidString
    try await provider.renameList(listID, name: "Personal")
    #expect(provider.taskLists[0].name == "Personal")
  }

  @Test func deleteNonDefaultListMovesTasksToDefault() async throws {
    let provider = makeProvider()
    try await provider.createList(name: "Secondary")
    let primaryID = provider.taskLists[0].id.uuidString  // Default = current default
    let secondaryID = provider.taskLists[1].id.uuidString

    // Promote "Secondary" so we can delete "Default"
    try await provider.setDefaultList(secondaryID)

    var draft = TaskDraft()
    draft.title = "Orphaned"
    draft.listID = primaryID
    try await provider.addTask(draft)

    try await provider.deleteList(primaryID)

    let secondaryList = TaskList(
      id: secondaryID, providerID: LocalProvider.providerID, name: "Secondary")
    let tasks = try await provider.tasks(in: secondaryList)
    #expect(tasks.map(\.title).contains("Orphaned"))
  }

  @Test func deleteDefaultListThrows() async {
    let provider = makeProvider()
    let defaultID = provider.defaultListID!
    await #expect(throws: LocalProviderError.self) {
      try await provider.deleteList(defaultID)
    }
  }

  @Test func renameListThrowsForUnknownID() async {
    let provider = makeProvider()
    let unknown = UUID().uuidString
    await #expect(throws: (any Error).self) {
      try await provider.renameList(unknown, name: "Ghost")
    }
  }

  @Test func deleteTaskThrowsForUnknownRef() async {
    let provider = makeProvider()
    let ref = TaskRef(providerID: LocalProvider.providerID, nativeID: UUID().uuidString)
    await #expect(throws: (any Error).self) {
      try await provider.deleteTask(ref)
    }
  }
}
