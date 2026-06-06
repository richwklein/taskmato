//
//  TaskRegistrySelectionTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

// MARK: - Fakes

private final class SelectionStubProvider: TaskProvider {
  let id: String
  let displayName: String
  let icon: String = "square"
  let entitlement: ProviderEntitlement = .free
  private let stubbedTasks: [TaskItem]
  private let stubbedLists: [TaskList]

  init(id: String, tasks: [TaskItem] = [], lists: [TaskList] = []) {
    self.id = id
    self.displayName = id
    self.stubbedTasks = tasks
    self.stubbedLists = lists
  }

  func authorize() async throws {}
  func lists() async throws -> [TaskList] { stubbedLists }
  func tasks(in _: TaskList?) async throws -> [TaskItem] { stubbedTasks }
  func observe() -> AsyncStream<[TaskItem]>? { nil }
}

private final class SelectionScopedProvider: TaskProvider {
  let id: String
  let displayName: String
  let icon: String = "square"
  let entitlement: ProviderEntitlement = .free
  private let stubbedLists: [TaskList]
  private let tasksByListID: [String: [TaskItem]]

  init(id: String, listTasks: [(TaskList, [TaskItem])]) {
    self.id = id
    self.displayName = id
    self.stubbedLists = listTasks.map(\.0)
    self.tasksByListID = Dictionary(uniqueKeysWithValues: listTasks.map { ($0.0.id, $0.1) })
  }

  func authorize() async throws {}
  func lists() async throws -> [TaskList] { stubbedLists }
  func tasks(in list: TaskList?) async throws -> [TaskItem] {
    guard let list else { return tasksByListID.values.flatMap { $0 } }
    return tasksByListID[list.id] ?? []
  }
  func observe() -> AsyncStream<[TaskItem]>? { nil }
}

private final class SelectionWritableProvider: WritableTaskProvider {
  let id: String
  let displayName: String
  let icon: String = "square"
  let entitlement: ProviderEntitlement = .free
  let defaultListID: String?

  init(id: String, defaultListID: String? = nil) {
    self.id = id
    self.displayName = id
    self.defaultListID = defaultListID
  }

  func authorize() async throws {}
  func lists() async throws -> [TaskList] { [] }
  func tasks(in _: TaskList?) async throws -> [TaskItem] { [] }
  func observe() -> AsyncStream<[TaskItem]>? { nil }
  func complete(_: TaskRef) async throws {}
  func reopen(_: TaskRef) async throws {}
  func completedTasks() async throws -> [TaskItem] { [] }
  @discardableResult
  func addTask(_: TaskDraft) async throws -> TaskItem { fatalError("unused") }
  func setDefaultList(_: String) async throws {}
  @discardableResult
  func createList(name _: String) async throws -> TaskList { fatalError("unused") }
  func renameList(_: String, name _: String) async throws {}
  func deleteList(_: String) async throws {}
  func updateTask(_: TaskRef, draft _: TaskDraft) async throws {}
  func deleteTask(_: TaskRef) async throws {}
}

private func selectionItem(
  providerID: String,
  title: String,
  dueDate: Date? = nil
) -> TaskItem {
  TaskItem(
    id: TaskRef(providerID: providerID, nativeID: UUID().uuidString),
    title: title,
    notes: nil,
    format: .plainText,
    priority: .none,
    dueDate: dueDate,
    scheduledDate: nil,
    startDate: nil,
    list: nil,
    section: nil,
    sourceURL: nil,
    completedAt: nil,
    createdAt: nil
  )
}

// MARK: - Tests

@Suite("TaskRegistry – Selection")
@MainActor
struct TaskRegistrySelectionTests {

  private func makeRegistry(defaults: UserDefaults? = nil) -> TaskRegistry {
    TaskRegistry(defaults: defaults ?? UserDefaults(suiteName: UUID().uuidString)!)
  }

  // MARK: - Default selection

  @Test func selectionDefaultsTodayOnFirstLaunch() {
    let registry = makeRegistry()
    #expect(registry.selection == .today)
  }

  // MARK: - Persistence

  @Test func selectionPersistsAcrossRegistryReloadForToday() {
    let defaults = UserDefaults(suiteName: UUID().uuidString)!
    let first = makeRegistry(defaults: defaults)
    first.select(.today)
    let second = makeRegistry(defaults: defaults)
    #expect(second.selection == .today)
  }

  @Test func selectionPersistsAcrossRegistryReloadForList() {
    let defaults = UserDefaults(suiteName: UUID().uuidString)!
    let target = SidebarSelection.list(SelectedList(providerID: "alpha", listID: "list-1"))
    let first = makeRegistry(defaults: defaults)
    first.select(target)
    let second = makeRegistry(defaults: defaults)
    #expect(second.selection == target)
  }

  // MARK: - providerLists cache

  @Test func setListsPopulatesProviderListsCache() {
    let registry = makeRegistry()
    let lists = [
      TaskList(id: "a", providerID: "alpha", name: "A"),
      TaskList(id: "b", providerID: "alpha", name: "B"),
    ]
    registry.setLists(lists, forProviderID: "alpha")
    #expect(registry.providerLists["alpha"]?.count == 2)
  }

  @Test func disableProviderClearsItsListsCache() {
    let registry = makeRegistry()
    let provider = SelectionStubProvider(id: "alpha")
    registry.register(provider)
    registry.enable(provider)
    registry.setLists([TaskList(id: "a", providerID: "alpha", name: "A")], forProviderID: "alpha")
    registry.disable(providerID: "alpha")
    #expect(registry.providerLists["alpha"] == nil)
  }

  // MARK: - validateSelection

  @Test func todaySelectionIsAlwaysValid() {
    let registry = makeRegistry()
    let provider = SelectionStubProvider(id: "alpha")
    registry.register(provider)
    registry.enable(provider)
    registry.select(.today)
    // With no lists loaded, validateSelection should still leave Today unchanged.
    registry.validateSelection()
    #expect(registry.selection == .today)
  }

  @Test func setListsTriggersValidationAndLeavesTodayUnchanged() {
    let registry = makeRegistry()
    let provider = SelectionStubProvider(id: "alpha")
    registry.register(provider)
    registry.enable(provider)
    // Selection is .today by default; setLists calls validateSelection internally.
    registry.setLists([TaskList(id: "a", providerID: "alpha", name: "A")], forProviderID: "alpha")
    #expect(registry.selection == .today)
  }

  @Test func validateSelectionDropsUnknownProvider() {
    let registry = makeRegistry()
    let staleSelection = SidebarSelection.list(
      SelectedList(providerID: "unknown-provider", listID: "list-1"))
    registry.select(staleSelection)
    registry.validateSelection()
    #expect(registry.selection == .today)
  }

  @Test func validateSelectionDropsUnknownListID() {
    let registry = makeRegistry()
    let provider = SelectionStubProvider(id: "alpha")
    registry.register(provider)
    registry.enable(provider)
    registry.select(.list(SelectedList(providerID: "alpha", listID: "missing-list")))
    // Populate cache with a different list ID.
    registry.setLists(
      [TaskList(id: "other", providerID: "alpha", name: "Other")], forProviderID: "alpha")
    #expect(registry.selection == .list(SelectedList(providerID: "alpha", listID: "other")))
  }

  @Test func validateSelectionFallsBackToWritableDefaultList() {
    let defaults = UserDefaults(suiteName: UUID().uuidString)!
    let registry = makeRegistry(defaults: defaults)
    let writable = SelectionWritableProvider(id: "local", defaultListID: "inbox")
    registry.register(writable)
    registry.enable(writable)
    // Populate the writable provider's lists in cache.
    let inboxList = TaskList(id: "inbox", providerID: "local", name: "Inbox")
    registry.setLists([inboxList], forProviderID: "local")
    // Now select a nonexistent list elsewhere.
    registry.select(.list(SelectedList(providerID: "ghost", listID: "gone")))
    registry.validateSelection()
    #expect(registry.selection == .list(SelectedList(providerID: "local", listID: "inbox")))
  }

  @Test func validateSelectionFallsBackToTodayWhenNoListsAvailable() {
    let registry = makeRegistry()
    let provider = SelectionStubProvider(id: "alpha")
    registry.register(provider)
    registry.enable(provider)
    registry.select(.list(SelectedList(providerID: "alpha", listID: "old-list")))
    // Populate cache with an empty list array.
    registry.setLists([], forProviderID: "alpha")
    #expect(registry.selection == .today)
  }

  // MARK: - Today fan-out

  @Test func todayFanOutFiltersToTasksDueOnOrBeforeToday() async {
    let registry = makeRegistry()
    let yesterday = Date().addingTimeInterval(-86400)
    let tomorrow = Date().addingTimeInterval(86400)

    let provider = SelectionStubProvider(
      id: "alpha",
      tasks: [
        selectionItem(providerID: "alpha", title: "Overdue", dueDate: yesterday),
        selectionItem(providerID: "alpha", title: "Due now", dueDate: Date()),
        selectionItem(providerID: "alpha", title: "Future", dueDate: tomorrow),
        selectionItem(providerID: "alpha", title: "No date"),
      ]
    )
    registry.register(provider)
    registry.enable(provider)

    let (tasks, _) = await registry.tasks(
      query: .crossProvider(filter: .dueUpToToday), sortBy: .priority, direction: .descending)
    let titles = tasks.map(\.title)
    #expect(titles.contains("Overdue"))
    #expect(titles.contains("Due now"))
    #expect(!titles.contains("Future"))
    #expect(!titles.contains("No date"))
  }

  // MARK: - List-scoped fan-out

  @Test func listSelectionScopesFanOutToOneList() async {
    let registry = makeRegistry()
    let listA = TaskList(id: "a", providerID: "alpha", name: "A")
    let listB = TaskList(id: "b", providerID: "alpha", name: "B")
    let taskA = selectionItem(providerID: "alpha", title: "Task in A")
    let taskB = selectionItem(providerID: "alpha", title: "Task in B")
    let provider = SelectionScopedProvider(
      id: "alpha", listTasks: [(listA, [taskA]), (listB, [taskB])])
    registry.register(provider)
    registry.enable(provider)
    registry.setLists([listA, listB], forProviderID: "alpha")

    let (tasks, _) = await registry.tasks(
      query: .singleList(SelectedList(providerID: "alpha", listID: "a")),
      sortBy: .priority, direction: .descending)
    #expect(tasks.count == 1)
    #expect(tasks[0].title == "Task in A")
  }

  @Test func listSelectionReturnsEmptyWhenCacheNotPopulated() async {
    let registry = makeRegistry()
    let provider = SelectionStubProvider(
      id: "alpha",
      tasks: [selectionItem(providerID: "alpha", title: "Some task")]
    )
    registry.register(provider)
    registry.enable(provider)
    // Do NOT call setLists — cache is empty.
    let (tasks, _) = await registry.tasks(
      query: .singleList(SelectedList(providerID: "alpha", listID: "x")),
      sortBy: .priority, direction: .descending)
    #expect(tasks.isEmpty)
  }

  // MARK: - Global search ignores selection

  @Test func nonEmptyQueryIgnoresSelectionAndFansOutGlobally() async {
    let registry = makeRegistry()
    let listA = TaskList(id: "a", providerID: "alpha", name: "A")
    let listB = TaskList(id: "b", providerID: "alpha", name: "B")
    let taskA = selectionItem(providerID: "alpha", title: "Write tests")
    let taskB = selectionItem(providerID: "alpha", title: "Review PR")
    let provider = SelectionScopedProvider(
      id: "alpha", listTasks: [(listA, [taskA]), (listB, [taskB])])
    registry.register(provider)
    registry.enable(provider)
    registry.setLists([listA, listB], forProviderID: "alpha")

    // Only list A is selected, but "Write tests" is there; "Review PR" is in B.
    // A non-empty query fans out across all lists.
    let (tasks, _) = await registry.tasks(
      query: .crossProvider(filter: .titleContains("Review")), sortBy: .priority,
      direction: .descending)
    #expect(tasks.count == 1)
    #expect(tasks[0].title == "Review PR")
  }

  // MARK: - Legacy key cleanup

  @Test func legacyScopeKeysAreRemovedOnInit() {
    let defaults = UserDefaults(suiteName: UUID().uuidString)!
    // Write dummy blobs for both legacy keys.
    defaults.set(Data([1, 2, 3]), forKey: "taskRegistry.providerListScopes")
    defaults.set(Data([4, 5, 6]), forKey: "taskRegistry.selectedList")
    _ = TaskRegistry(defaults: defaults)
    #expect(defaults.data(forKey: "taskRegistry.providerListScopes") == nil)
    #expect(defaults.data(forKey: "taskRegistry.selectedList") == nil)
  }
}
