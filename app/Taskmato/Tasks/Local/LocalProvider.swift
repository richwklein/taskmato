//
//  LocalProvider.swift
//  Taskmato
//

import Foundation
import Observation
import os

/// A built-in task provider that persists tasks and lists to a JSON file in Application Support.
///
/// Unlike the Obsidian provider, `LocalProvider` does not scan any external directory. All
/// task CRUD happens in-process; `observe()` returns `nil` because the `@Observable` machinery
/// propagates changes directly to SwiftUI views. Completion state is stored as a soft-delete
/// so completed tasks can be surfaced via ``completedTasks()``.
@Observable
@MainActor
final class LocalProvider: WritableTaskProvider {

  /// Stable provider identifier used in ``TaskRef`` values.
  nonisolated static let providerID: ProviderID = "local"

  let id: ProviderID = LocalProvider.providerID
  let displayName: String = "Local"
  let displayOrder: Int = 0
  let icon: String = "tray"
  let tint: ProviderTint = .green
  let entitlement: ProviderEntitlement = .free

  /// Local tasks always support inline Markdown for titles and notes.
  let contentFormat: ContentFormat = .markdown

  /// Lists managed by this provider, in creation order.
  private(set) var taskLists: [LocalList] = []

  /// The ID of the list new tasks are added to by default.
  ///
  /// Always non-`nil` after initialisation; the first list is used until the user
  /// explicitly promotes another list via ``setDefaultList(_:)``.
  private(set) var defaultListID: String?

  /// Number of incomplete tasks currently in the store.
  var activeTaskCount: Int { allTasks.filter { !$0.isCompleted }.count }

  private var allTasks: [LocalTask] = []
  private let repository: any LocalTaskRepository
  private let logger = Logger(subsystem: "com.taskmato", category: "LocalProvider")

  /// The initial load fired from ``init(repository:)``. Awaited via ``ready()``.
  private var loadTask: Task<Void, Never>?

  /// Creates a provider backed by the default production JSON repository.
  convenience init() {
    self.init(
      repository: JSONLocalTaskRepository(fileURL: JSONLocalTaskRepository.defaultFileURL()))
  }

  /// Creates a provider backed by a specific file URL. Pass a temporary path in tests.
  convenience init(fileURL: URL) {
    self.init(repository: JSONLocalTaskRepository(fileURL: fileURL))
  }

  /// Creates a provider backed by an injected repository. Pass a fake repository in tests.
  ///
  /// The store loads asynchronously — the observable state populates moments after this
  /// initializer returns. Await ``ready()`` in tests that need the load to have completed.
  init(repository: any LocalTaskRepository) {
    self.repository = repository
    loadTask = Task { await self.reload() }
  }

  /// Awaits the initial load fired from ``init(repository:)``.
  ///
  /// There is exactly one in-flight load per provider instance: the one started by `init`.
  /// ``lists()``, ``tasks(in:)``, and ``completedTasks()`` await this before reading state, so
  /// a query issued moments after construction — as `AppSidebarView`'s one-shot startup
  /// `.task` does — can no longer observe the pre-load empty state and cache it permanently
  /// (the underlying regression: the old synchronous `init` made this impossible since loading
  /// always completed before construction returned). Tests that need state populated before
  /// asserting should await this rather than calling ``reload()`` again, which would race the
  /// initial load.
  func ready() async {
    await loadTask?.value
  }

  // MARK: - TaskProvider

  /// No-op — local tasks require no external authorization.
  func authorize() async throws {}

  /// Returns the managed lists expressed as provider-agnostic ``TaskList`` values.
  func lists() async throws -> [TaskList] {
    await ready()
    return taskLists.map(\.asTaskList)
  }

  /// Returns incomplete tasks, optionally scoped to a single list.
  ///
  /// - Parameter list: Scope results to a specific list, or `nil` for all incomplete tasks.
  func tasks(in list: TaskList?) async throws -> [TaskItem] {
    await ready()
    let incomplete = allTasks.filter { !$0.isCompleted }
    if let list {
      let listID = UUID(uuidString: list.id)
      return incomplete.filter { $0.listID == listID }.map { $0.asTaskItem(lists: taskLists) }
    }
    return incomplete.map { $0.asTaskItem(lists: taskLists) }
  }

  /// Returns `nil` — mutations are in-process and `@Observable` propagates changes directly.
  func observe() -> AsyncStream<[TaskItem]>? { nil }

  // MARK: - ClosableTaskProvider

  /// Soft-deletes the task by setting `isCompleted = true` and recording `completedAt`.
  func complete(_ ref: TaskRef) async throws {
    guard let idx = allTasks.firstIndex(where: { $0.id.uuidString == ref.nativeID }) else {
      throw LocalProviderError.taskNotFound(ref.nativeID)
    }
    allTasks[idx].isCompleted = true
    allTasks[idx].completedAt = Date()
    await persist()
  }

  /// Restores a completed task by clearing `isCompleted` and `completedAt`.
  func reopen(_ ref: TaskRef) async throws {
    guard let idx = allTasks.firstIndex(where: { $0.id.uuidString == ref.nativeID }) else {
      throw LocalProviderError.taskNotFound(ref.nativeID)
    }
    allTasks[idx].isCompleted = false
    allTasks[idx].completedAt = nil
    await persist()
  }

  /// Returns all soft-deleted tasks, sorted by completion date descending.
  func completedTasks() async throws -> [TaskItem] {
    await ready()
    return
      allTasks
      .filter { $0.isCompleted }
      .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
      .map { $0.asTaskItem(lists: taskLists) }
  }

  // MARK: - WritableTaskProvider: task creation

  /// Appends a new task built from `draft` to the store and returns the created ``TaskItem``.
  ///
  /// If `draft.listID` is `nil`, the task is assigned to the provider's default list.
  @discardableResult
  func addTask(_ draft: TaskDraft) async throws -> TaskItem {
    var resolved = draft
    if resolved.listID == nil {
      resolved.listID = defaultListID ?? taskLists.first?.id.uuidString
    }
    let newTask = LocalTask(from: resolved)
    allTasks.append(newTask)
    await persist()
    return newTask.asTaskItem(lists: taskLists)
  }

  /// Persists `listID` as the default target for new tasks.
  func setDefaultList(_ listID: String) async throws {
    guard taskLists.contains(where: { $0.id.uuidString == listID }) else {
      throw LocalProviderError.listNotFound(listID)
    }
    defaultListID = listID
    await persist()
  }

  /// Applies `draft` to the task identified by `ref`.
  func updateTask(_ ref: TaskRef, draft: TaskDraft) async throws {
    guard let idx = allTasks.firstIndex(where: { $0.id.uuidString == ref.nativeID }) else {
      throw LocalProviderError.taskNotFound(ref.nativeID)
    }
    allTasks[idx].apply(draft)
    await persist()
  }

  /// Permanently removes the task identified by `ref` from the store.
  func deleteTask(_ ref: TaskRef) async throws {
    guard allTasks.contains(where: { $0.id.uuidString == ref.nativeID }) else {
      throw LocalProviderError.taskNotFound(ref.nativeID)
    }
    allTasks.removeAll { $0.id.uuidString == ref.nativeID }
    await persist()
  }

  // MARK: - WritableTaskProvider: list management

  /// Appends a new list with the given name and returns the provider-agnostic ``TaskList``.
  @discardableResult
  func createList(name: String) async throws -> TaskList {
    let list = LocalList(id: UUID(), name: name, createdAt: Date())
    taskLists.append(list)
    await persist()
    return list.asTaskList
  }

  /// Renames the list identified by `listID` to `name`.
  func renameList(_ listID: String, name: String) async throws {
    guard let idx = taskLists.firstIndex(where: { $0.id.uuidString == listID }) else {
      throw LocalProviderError.listNotFound(listID)
    }
    taskLists[idx].name = name
    await persist()
  }

  /// Deletes the list identified by `listID`, reassigning its tasks to the default list.
  ///
  /// Throws ``LocalProviderError/cannotDeleteDefaultList(_:)`` when `listID` is the
  /// current default. Promote another list via ``setDefaultList(_:)`` first.
  func deleteList(_ listID: String) async throws {
    guard listID != defaultListID else {
      throw LocalProviderError.cannotDeleteDefaultList(listID)
    }
    guard let uuid = UUID(uuidString: listID),
      taskLists.contains(where: { $0.id == uuid })
    else {
      throw LocalProviderError.listNotFound(listID)
    }
    taskLists.removeAll { $0.id == uuid }
    let fallbackID = UUID(uuidString: defaultListID ?? "") ?? taskLists[0].id
    for idx in allTasks.indices where allTasks[idx].listID == uuid {
      allTasks[idx].listID = fallbackID
    }
    await persist()
  }

  // MARK: - Persistence

  /// Loads the store from the repository and normalizes default-list invariants.
  ///
  /// Called once from ``init(repository:)``; awaited by tests and callers via ``ready()``.
  /// On a read/decode failure this returns immediately, leaving the provider's in-memory
  /// state at its empty initial values — it does **not** fall through into the default-list
  /// normalization below, which would otherwise treat the empty in-memory state as "no lists
  /// yet" and persist a fresh empty store over the corrupt file. Note this only protects the
  /// file while the provider is idle: a subsequent mutator (``addTask(_:)``,
  /// ``createList(name:)``, etc.) still calls ``persist()`` unconditionally and will overwrite
  /// the primary file with fresh content. A successful load — including the legitimate "file
  /// doesn't exist yet" empty-store case, which does not throw — proceeds into normalization
  /// as usual.
  func reload() async {
    let stored: LocalStore
    do {
      stored = try await repository.loadAll()
    } catch {
      logger.error("LocalProvider failed to load: \(error.localizedDescription, privacy: .public)")
      return
    }
    taskLists = stored.lists
    allTasks = stored.tasks
    defaultListID = stored.defaultListID

    var dirty = false
    if taskLists.isEmpty {
      taskLists.append(LocalList(id: UUID(), name: "Default", createdAt: Date()))
      dirty = true
    }
    let firstID = taskLists[0].id
    for idx in allTasks.indices where allTasks[idx].listID == nil {
      allTasks[idx].listID = firstID
      dirty = true
    }
    // Ensure defaultListID is always set to a valid list.
    if defaultListID == nil || !taskLists.contains(where: { $0.id.uuidString == defaultListID }) {
      defaultListID = firstID.uuidString
      dirty = true
    }
    if dirty { await persist() }
  }

  private func persist() async {
    let store = LocalStore(lists: taskLists, tasks: allTasks, defaultListID: defaultListID)
    do {
      try await repository.save(store)
    } catch {
      logger.error("LocalProvider failed to save: \(error.localizedDescription, privacy: .public)")
    }
  }
}

// MARK: - Errors

/// Errors thrown by ``LocalProvider`` operations.
enum LocalProviderError: LocalizedError {

  /// No task matching the given native ID exists in the store.
  case taskNotFound(String)

  /// No list matching the given ID exists in the store.
  case listNotFound(String)

  /// The list cannot be deleted because it is the current default list.
  case cannotDeleteDefaultList(String)

  var errorDescription: String? {
    switch self {
    case .taskNotFound(let nativeID):
      return "Could not find task \"\(nativeID)\"."
    case .listNotFound(let listID):
      return "Could not find list \"\(listID)\"."
    case .cannotDeleteDefaultList(let listID):
      return "Cannot delete the default list \"\(listID)\". Promote another list first."
    }
  }
}
