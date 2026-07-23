//
//  TaskQueryServiceTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

// MARK: - Fakes

private struct QueryStubError: Error, Equatable {}

/// Returns a fixed task set from `tasks(in:)` regardless of the requested list.
private final class QueryStubProvider: TaskProvider {
  let id: String
  let displayName: String
  let icon: String = "square"
  let entitlement: ProviderEntitlement = .free
  private let stubbedTasks: [TaskItem]
  private let stubbedLists: [TaskList]
  private let shouldThrow: Bool

  init(id: String, tasks: [TaskItem] = [], lists: [TaskList] = [], shouldThrow: Bool = false) {
    self.id = id
    self.displayName = id
    self.stubbedTasks = tasks
    self.stubbedLists = lists
    self.shouldThrow = shouldThrow
  }

  func authorize() async throws {}
  func lists() async throws -> [TaskList] { stubbedLists }
  func tasks(in _: TaskList?) async throws -> [TaskItem] {
    if shouldThrow { throw QueryStubError() }
    return stubbedTasks
  }
  func observe() -> AsyncStream<[TaskItem]>? { nil }
}

/// Scopes returned tasks to the requested list, so single-list queries can be exercised.
private final class QueryScopedProvider: TaskProvider {
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

private func queryItem(
  providerID: String = "p",
  nativeID: String = UUID().uuidString,
  title: String,
  priority: TaskPriority = .none,
  dueDate: Date? = nil,
  list: TaskList? = nil,
  section: String? = nil
) -> TaskItem {
  TaskItem(
    id: TaskRef(providerID: providerID, nativeID: nativeID),
    title: title,
    notes: nil,
    format: .plainText,
    priority: priority,
    dueDate: dueDate,
    scheduledDate: nil,
    startDate: nil,
    list: list,
    section: section,
    sourceURL: nil,
    completedAt: nil,
    createdAt: nil
  )
}

// MARK: - Tests

@Suite("TaskQueryService")
@MainActor
struct TaskQueryServiceTests {

  private func makeRegistry() -> ProviderRegistry {
    ProviderRegistry(defaults: UserDefaults(suiteName: UUID().uuidString)!)
  }

  private func makeService(_ registry: ProviderRegistry) -> TaskQueryService {
    TaskQueryService(registry: registry, sorter: TaskSorter())
  }

  // MARK: - Cross-provider fan-out

  @Test func tasksAcrossTwoProviders() async {
    let registry = makeRegistry()
    let alpha = QueryStubProvider(
      id: "alpha", tasks: [queryItem(providerID: "alpha", title: "Alpha task")])
    let beta = QueryStubProvider(
      id: "beta", tasks: [queryItem(providerID: "beta", title: "Beta task")])
    registry.register(alpha)
    registry.register(beta)
    registry.enable(alpha)
    registry.enable(beta)

    let (tasks, errors) = await makeService(registry).tasks(
      query: .crossProvider(), sortBy: .priority, direction: .descending)
    #expect(tasks.count == 2)
    #expect(errors.isEmpty)
  }

  @Test func disabledProviderExcludedFromFanOut() async {
    let registry = makeRegistry()
    let alpha = QueryStubProvider(
      id: "alpha", tasks: [queryItem(providerID: "alpha", title: "Alpha task")])
    let beta = QueryStubProvider(
      id: "beta", tasks: [queryItem(providerID: "beta", title: "Beta task")])
    registry.register(alpha)
    registry.register(beta)
    registry.enable(alpha)

    let (tasks, errors) = await makeService(registry).tasks(
      query: .crossProvider(), sortBy: .priority, direction: .descending)
    #expect(tasks.count == 1)
    #expect(tasks[0].id.providerID == "alpha")
    #expect(errors.isEmpty)
  }

  @Test func taskSearchFiltersOnTitle() async {
    let registry = makeRegistry()
    let provider = QueryStubProvider(
      id: "alpha",
      tasks: [
        queryItem(providerID: "alpha", title: "Write tests"),
        queryItem(providerID: "alpha", title: "Review PR"),
      ])
    registry.register(provider)
    registry.enable(provider)

    let (tasks, errors) = await makeService(registry).tasks(
      query: .crossProvider(filter: .titleContains("write")),
      sortBy: .priority, direction: .descending)
    #expect(tasks.count == 1)
    #expect(tasks[0].title == "Write tests")
    #expect(errors.isEmpty)
  }

  @Test func tasksSortedByPriorityDescending() async {
    let registry = makeRegistry()
    let provider = QueryStubProvider(
      id: "alpha",
      tasks: [
        queryItem(providerID: "alpha", title: "Low", priority: .low),
        queryItem(providerID: "alpha", title: "High", priority: .high),
        queryItem(providerID: "alpha", title: "Medium", priority: .medium),
      ])
    registry.register(provider)
    registry.enable(provider)

    let (tasks, _) = await makeService(registry).tasks(
      query: .crossProvider(), sortBy: .priority, direction: .descending)
    #expect(tasks.map(\.title) == ["High", "Medium", "Low"])
  }

  @Test func samePriorityTasksSortedByDueDateAscending() async {
    let registry = makeRegistry()
    let earlier = Date(timeIntervalSince1970: 1_000)
    let later = Date(timeIntervalSince1970: 2_000)
    let provider = QueryStubProvider(
      id: "alpha",
      tasks: [
        queryItem(providerID: "alpha", title: "Later", dueDate: later),
        queryItem(providerID: "alpha", title: "Earlier", dueDate: earlier),
      ])
    registry.register(provider)
    registry.enable(provider)

    let (tasks, _) = await makeService(registry).tasks(
      query: .crossProvider(), sortBy: .priority, direction: .descending)
    #expect(tasks.map(\.title) == ["Earlier", "Later"])
  }

  @Test func failingProviderErrorSurfacedOtherTasksReturned() async {
    let registry = makeRegistry()
    let good = QueryStubProvider(
      id: "good", tasks: [queryItem(providerID: "good", title: "Good task")])
    let bad = QueryStubProvider(id: "bad", shouldThrow: true)
    registry.register(good)
    registry.register(bad)
    registry.enable(good)
    registry.enable(bad)

    let (tasks, errors) = await makeService(registry).tasks(
      query: .crossProvider(), sortBy: .priority, direction: .descending)
    #expect(tasks.count == 1)
    #expect(tasks[0].id.providerID == "good")
    #expect(errors.count == 1)
    #expect(errors[0].providerID == "bad")
    #expect(errors[0].error is QueryStubError)
  }

  // MARK: - Today filter

  @Test func todayFanOutFiltersToTasksDueOnOrBeforeToday() async {
    let registry = makeRegistry()
    let yesterday = Date().addingTimeInterval(-86400)
    let tomorrow = Date().addingTimeInterval(86400)
    let provider = QueryStubProvider(
      id: "alpha",
      tasks: [
        queryItem(providerID: "alpha", title: "Overdue", dueDate: yesterday),
        queryItem(providerID: "alpha", title: "Due now", dueDate: Date()),
        queryItem(providerID: "alpha", title: "Future", dueDate: tomorrow),
        queryItem(providerID: "alpha", title: "No date"),
      ])
    registry.register(provider)
    registry.enable(provider)

    let (tasks, _) = await makeService(registry).tasks(
      query: .crossProvider(filter: .dueUpToToday), sortBy: .priority, direction: .descending)
    let titles = tasks.map(\.title)
    #expect(titles.contains("Overdue"))
    #expect(titles.contains("Due now"))
    #expect(!titles.contains("Future"))
    #expect(!titles.contains("No date"))
  }

  // MARK: - Single-list scope

  @Test func listSelectionScopesFanOutToOneList() async {
    let registry = makeRegistry()
    let listA = TaskList(id: "a", providerID: "alpha", name: "A")
    let listB = TaskList(id: "b", providerID: "alpha", name: "B")
    let taskA = queryItem(providerID: "alpha", title: "Task in A")
    let taskB = queryItem(providerID: "alpha", title: "Task in B")
    let provider = QueryScopedProvider(
      id: "alpha", listTasks: [(listA, [taskA]), (listB, [taskB])])
    registry.register(provider)
    registry.enable(provider)
    registry.setLists([listA, listB], forProviderID: "alpha")

    let (tasks, _) = await makeService(registry).tasks(
      query: .singleList(SelectedList(providerID: "alpha", listID: "a")),
      sortBy: .priority, direction: .descending)
    #expect(tasks.count == 1)
    #expect(tasks[0].title == "Task in A")
  }

  @Test func listSelectionReturnsEmptyWhenCacheNotPopulated() async {
    let registry = makeRegistry()
    let provider = QueryStubProvider(
      id: "alpha", tasks: [queryItem(providerID: "alpha", title: "Some task")])
    registry.register(provider)
    registry.enable(provider)
    // Do NOT call setLists — cache is empty and the provider exposes no lists.
    let (tasks, _) = await makeService(registry).tasks(
      query: .singleList(SelectedList(providerID: "alpha", listID: "x")),
      sortBy: .priority, direction: .descending)
    #expect(tasks.isEmpty)
  }

  @Test func nonEmptyQueryIgnoresSelectionAndFansOutGlobally() async {
    let registry = makeRegistry()
    let listA = TaskList(id: "a", providerID: "alpha", name: "A")
    let listB = TaskList(id: "b", providerID: "alpha", name: "B")
    let taskA = queryItem(providerID: "alpha", title: "Write tests")
    let taskB = queryItem(providerID: "alpha", title: "Review PR")
    let provider = QueryScopedProvider(
      id: "alpha", listTasks: [(listA, [taskA]), (listB, [taskB])])
    registry.register(provider)
    registry.enable(provider)
    registry.setLists([listA, listB], forProviderID: "alpha")

    // A non-empty cross-provider query fans out across all lists regardless of scope.
    let (tasks, _) = await makeService(registry).tasks(
      query: .crossProvider(filter: .titleContains("Review")), sortBy: .priority,
      direction: .descending)
    #expect(tasks.count == 1)
    #expect(tasks[0].title == "Review PR")
  }

  // MARK: - Query scope → section behavior

  @Test func singleListPreservesSectionOrderSortingWithinSection() async {
    let registry = makeRegistry()
    let list = TaskList(id: "list1", providerID: "p", name: "List 1")
    let provider = QueryStubProvider(
      id: "p",
      tasks: [
        queryItem(nativeID: "alpha-c", title: "C", list: list, section: "Alpha"),
        queryItem(nativeID: "alpha-a", title: "A", list: list, section: "Alpha"),
        queryItem(nativeID: "beta-d", title: "D", list: list, section: "Beta"),
        queryItem(nativeID: "beta-b", title: "B", list: list, section: "Beta"),
      ])
    registry.register(provider)
    registry.enable(provider)
    registry.setLists([list], forProviderID: "p")

    let (tasks, _) = await makeService(registry).tasks(
      query: .singleList(SelectedList(providerID: "p", listID: "list1")),
      sortBy: .title, direction: .ascending)
    // Sections keep encounter order (Alpha before Beta); titles sorted within each section.
    #expect(tasks.map(\.id.nativeID) == ["alpha-a", "alpha-c", "beta-b", "beta-d"])
  }

  @Test func singleListKeepsEarlierSectionAheadOfEarlierDueDate() async {
    let registry = makeRegistry()
    let list = TaskList(id: "l1", providerID: "p", name: "L1")
    let earlier = Date(timeIntervalSinceNow: -7200)
    let later = Date(timeIntervalSinceNow: -3600)
    let provider = QueryStubProvider(
      id: "p",
      tasks: [
        queryItem(
          nativeID: "alpha-later", title: "A", dueDate: later, list: list, section: "Alpha"),
        queryItem(
          nativeID: "beta-earlier", title: "B", dueDate: earlier, list: list, section: "Beta"),
      ])
    registry.register(provider)
    registry.enable(provider)
    registry.setLists([list], forProviderID: "p")

    let (tasks, _) = await makeService(registry).tasks(
      query: .singleList(SelectedList(providerID: "p", listID: "l1")),
      sortBy: .dueDate, direction: .ascending)
    // Alpha section encountered first → alpha-later stays before beta-earlier.
    #expect(tasks.map(\.id.nativeID) == ["alpha-later", "beta-earlier"])
  }

  @Test func crossProviderSortsAcrossSectionBoundaries() async {
    let registry = makeRegistry()
    let list = TaskList(id: "l1", providerID: "p", name: "L1")
    let earlier = Date(timeIntervalSinceNow: -7200)
    let later = Date(timeIntervalSinceNow: -3600)
    let provider = QueryStubProvider(
      id: "p",
      tasks: [
        queryItem(
          nativeID: "alpha-later", title: "A", dueDate: later, list: list, section: "Alpha"),
        queryItem(
          nativeID: "beta-earlier", title: "B", dueDate: earlier, list: list, section: "Beta"),
      ])
    registry.register(provider)
    registry.enable(provider)

    let (tasks, _) = await makeService(registry).tasks(
      query: .crossProvider(filter: .dueUpToToday),
      sortBy: .dueDate, direction: .ascending)
    // Flat sort ignores section encounter order — beta-earlier has an earlier date.
    #expect(tasks.map(\.id.nativeID) == ["beta-earlier", "alpha-later"])
  }

  @Test func crossProviderTitleFilterSortsAcrossSectionBoundaries() async {
    let registry = makeRegistry()
    let list = TaskList(id: "l1", providerID: "p", name: "L1")
    let earlier = Date(timeIntervalSinceNow: -7200)
    let later = Date(timeIntervalSinceNow: -3600)
    let provider = QueryStubProvider(
      id: "p",
      tasks: [
        queryItem(
          nativeID: "alpha-later", title: "deploy Alpha", dueDate: later, list: list,
          section: "Alpha"),
        queryItem(
          nativeID: "beta-earlier", title: "deploy Beta", dueDate: earlier, list: list,
          section: "Beta"),
      ])
    registry.register(provider)
    registry.enable(provider)

    let (tasks, _) = await makeService(registry).tasks(
      query: .crossProvider(filter: .titleContains("deploy")),
      sortBy: .dueDate, direction: .ascending)
    #expect(tasks.map(\.id.nativeID) == ["beta-earlier", "alpha-later"])
  }
}
