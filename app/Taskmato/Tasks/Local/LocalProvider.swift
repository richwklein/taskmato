//
//  LocalProvider.swift
//  Taskmato
//

import Foundation
import Observation

/// A built-in task provider that persists tasks and lists to a JSON file in Application Support.
///
/// Unlike the Obsidian provider, `LocalProvider` does not scan any external directory. All
/// task CRUD happens in-process; `observe()` returns `nil` because the `@Observable` machinery
/// propagates changes directly to SwiftUI views. Completion state is stored as a soft-delete
/// so completed tasks can be surfaced via ``completedTasks()``.
@Observable
@MainActor
final class LocalProvider: MutableTaskProvider {

  /// Stable provider identifier used in ``TaskRef`` values.
  static let providerID = "local"

  let id: String = LocalProvider.providerID
  let displayName: String = "Local"
  let entitlement: ProviderEntitlement = .free

  /// Lists managed by this provider, in creation order.
  private(set) var taskLists: [LocalList] = []

  /// Number of incomplete tasks currently in the store.
  var activeTaskCount: Int { allTasks.filter { !$0.isCompleted }.count }

  private var allTasks: [LocalTask] = []
  private let fileURL: URL
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  /// Creates a provider backed by the default production file path.
  convenience init() {
    let appSupport = FileManager.default.urls(
      for: .applicationSupportDirectory, in: .userDomainMask
    ).first!
    let dir = appSupport.appendingPathComponent("Taskmato", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    self.init(fileURL: dir.appendingPathComponent("local-tasks.json"))
  }

  /// Creates a provider backed by a specific file URL. Pass a temporary path in tests.
  init(fileURL: URL) {
    self.fileURL = fileURL
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    decoder.dateDecodingStrategy = .iso8601
    load()
  }

  // MARK: - TaskProvider

  /// No-op — local tasks require no external authorization.
  func authorize() async throws {}

  /// Returns the managed lists expressed as provider-agnostic ``TaskList`` values.
  func lists() async throws -> [TaskList] {
    taskLists.map(\.asTaskList)
  }

  /// Returns incomplete tasks, optionally scoped to a single list.
  ///
  /// - Parameter list: Scope results to a specific list, or `nil` for all incomplete tasks.
  func tasks(in list: TaskList?) async throws -> [TaskItem] {
    let incomplete = allTasks.filter { !$0.isCompleted }
    if let list {
      let listID = UUID(uuidString: list.id)
      return incomplete.filter { $0.listID == listID }.map { $0.asTaskItem(lists: taskLists) }
    }
    return incomplete.map { $0.asTaskItem(lists: taskLists) }
  }

  /// Returns `nil` — mutations are in-process and `@Observable` propagates changes directly.
  func observe() -> AsyncStream<[TaskItem]>? { nil }

  // MARK: - MutableTaskProvider

  /// Soft-deletes the task by setting `isCompleted = true` and recording `completedAt`.
  func complete(_ ref: TaskRef) async throws {
    guard let idx = allTasks.firstIndex(where: { $0.id.uuidString == ref.nativeID }) else {
      throw LocalProviderError.taskNotFound(ref.nativeID)
    }
    allTasks[idx].isCompleted = true
    allTasks[idx].completedAt = Date()
    save()
  }

  /// Restores a completed task by clearing `isCompleted` and `completedAt`.
  func reopen(_ ref: TaskRef) async throws {
    guard let idx = allTasks.firstIndex(where: { $0.id.uuidString == ref.nativeID }) else {
      throw LocalProviderError.taskNotFound(ref.nativeID)
    }
    allTasks[idx].isCompleted = false
    allTasks[idx].completedAt = nil
    save()
  }

  /// Returns all soft-deleted tasks, sorted by completion date descending.
  func completedTasks() async throws -> [TaskItem] {
    allTasks
      .filter { $0.isCompleted }
      .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
      .map { $0.asTaskItem(lists: taskLists) }
  }

  // MARK: - Task CRUD

  /// Appends a new task built from `draft` to the store.
  ///
  /// If `draft.listID` is `nil`, the task is assigned to the first available list.
  func addTask(_ draft: TaskDraft) {
    var resolved = draft
    if resolved.listID == nil {
      resolved.listID = taskLists.first?.id
    }
    allTasks.append(LocalTask(from: resolved))
    save()
  }

  /// Applies `draft` to the task identified by `ref`.
  func updateTask(_ ref: TaskRef, draft: TaskDraft) throws {
    guard let idx = allTasks.firstIndex(where: { $0.id.uuidString == ref.nativeID }) else {
      throw LocalProviderError.taskNotFound(ref.nativeID)
    }
    allTasks[idx].apply(draft)
    save()
  }

  /// Permanently removes the task identified by `ref` from the store.
  func deleteTask(_ ref: TaskRef) throws {
    guard allTasks.contains(where: { $0.id.uuidString == ref.nativeID }) else {
      throw LocalProviderError.taskNotFound(ref.nativeID)
    }
    allTasks.removeAll { $0.id.uuidString == ref.nativeID }
    save()
  }

  // MARK: - List CRUD

  /// Appends a new list with the given name.
  func createList(name: String) {
    taskLists.append(LocalList(id: UUID(), name: name))
    save()
  }

  /// Renames the list with `listID` to `name`.
  func renameList(_ listID: UUID, name: String) throws {
    guard let idx = taskLists.firstIndex(where: { $0.id == listID }) else {
      throw LocalProviderError.listNotFound(listID.uuidString)
    }
    taskLists[idx].name = name
    save()
  }

  /// Deletes the list with `listID` and moves its tasks to the next available list,
  /// creating a "Default" list first if this was the last one.
  func deleteList(_ listID: UUID) {
    taskLists.removeAll { $0.id == listID }
    if taskLists.isEmpty {
      taskLists.append(LocalList(id: UUID(), name: "Default"))
    }
    let fallbackID = taskLists[0].id
    for idx in allTasks.indices where allTasks[idx].listID == listID {
      allTasks[idx].listID = fallbackID
    }
    save()
  }

  // MARK: - Persistence

  private func load() {
    if let data = try? Data(contentsOf: fileURL) {
      let stored = try? decoder.decode(LocalStore.self, from: data)
      taskLists = stored?.lists ?? []
      allTasks = stored?.tasks ?? []
    }
    var dirty = false
    if taskLists.isEmpty {
      taskLists.append(LocalList(id: UUID(), name: "Default"))
      dirty = true
    }
    let defaultID = taskLists[0].id
    for idx in allTasks.indices where allTasks[idx].listID == nil {
      allTasks[idx].listID = defaultID
      dirty = true
    }
    if dirty { save() }
  }

  private func save() {
    let store = LocalStore(lists: taskLists, tasks: allTasks)
    guard let data = try? encoder.encode(store) else { return }
    try? data.write(to: fileURL, options: [])
  }
}

// MARK: - Persistence container

/// Top-level JSON container for the local task store.
private struct LocalStore: Codable {
  var lists: [LocalList]
  var tasks: [LocalTask]
}

// MARK: - Errors

/// Errors thrown by ``LocalProvider`` operations.
enum LocalProviderError: LocalizedError {

  /// No task matching the given native ID exists in the store.
  case taskNotFound(String)

  /// No list matching the given ID exists in the store.
  case listNotFound(String)

  var errorDescription: String? {
    switch self {
    case .taskNotFound(let nativeID):
      return "Could not find task \"\(nativeID)\"."
    case .listNotFound(let listID):
      return "Could not find list \"\(listID)\"."
    }
  }
}
