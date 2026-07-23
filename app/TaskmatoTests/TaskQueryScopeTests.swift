//
//  TaskQueryScopeTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

// MARK: - Fakes

private final class ScopeStubProvider: TaskProvider {
  let id: String
  let displayName: String
  let icon: String = "square"
  let entitlement: ProviderEntitlement = .free
  var stubbedItems: [TaskItem]

  init(id: String, items: [TaskItem]) {
    self.id = id
    self.displayName = id
    self.stubbedItems = items
  }

  func authorize() async throws {}
  func lists() async throws -> [TaskList] { [] }
  func tasks(in _: TaskList?) async throws -> [TaskItem] { stubbedItems }
  func observe() -> AsyncStream<[TaskItem]>? { nil }
}

private func makeScopeItem(
  nativeID: String,
  title: String,
  dueDate: Date? = nil,
  list: TaskList? = nil,
  section: String? = nil
) -> TaskItem {
  TaskItem(
    id: TaskRef(providerID: "p", nativeID: nativeID),
    title: title,
    notes: nil,
    format: .plainText,
    priority: .none,
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

/// Integration checks for the mapping the query layer applies between query scope and
/// section handling: a `.singleList` query preserves provider section encounter order,
/// while `.crossProvider` sorts flat. Pure ordering mechanics live in ``TaskSorterTests``.
@Suite("Task query scope")
@MainActor
struct TaskQueryScopeTests {

  private func makeRegistry(items: [TaskItem]) -> TaskRegistry {
    let registry = TaskRegistry(defaults: UserDefaults(suiteName: UUID().uuidString)!)
    let provider = ScopeStubProvider(id: "p", items: items)
    registry.register(provider)
    registry.enable(provider)
    return registry
  }

  @Test func singleListPreservesSectionOrderSortingWithinSection() async {
    let list = TaskList(id: "list1", providerID: "p", name: "List 1")
    let registry = makeRegistry(items: [
      makeScopeItem(nativeID: "alpha-c", title: "C", list: list, section: "Alpha"),
      makeScopeItem(nativeID: "alpha-a", title: "A", list: list, section: "Alpha"),
      makeScopeItem(nativeID: "beta-d", title: "D", list: list, section: "Beta"),
      makeScopeItem(nativeID: "beta-b", title: "B", list: list, section: "Beta"),
    ])
    registry.setLists([list], forProviderID: "p")

    let (tasks, _) = await registry.tasks(
      query: .singleList(SelectedList(providerID: "p", listID: "list1")),
      sortBy: .title, direction: .ascending)
    // Sections keep encounter order (Alpha before Beta); titles sorted within each section.
    #expect(tasks.map(\.id.nativeID) == ["alpha-a", "alpha-c", "beta-b", "beta-d"])
  }

  @Test func singleListKeepsEarlierSectionAheadOfEarlierDueDate() async {
    let list = TaskList(id: "l1", providerID: "p", name: "L1")
    let earlier = Date(timeIntervalSinceNow: -7200)
    let later = Date(timeIntervalSinceNow: -3600)
    let registry = makeRegistry(items: [
      makeScopeItem(
        nativeID: "alpha-later", title: "A", dueDate: later, list: list, section: "Alpha"),
      makeScopeItem(
        nativeID: "beta-earlier", title: "B", dueDate: earlier, list: list, section: "Beta"),
    ])
    registry.setLists([list], forProviderID: "p")

    let (tasks, _) = await registry.tasks(
      query: .singleList(SelectedList(providerID: "p", listID: "l1")),
      sortBy: .dueDate, direction: .ascending)
    // Alpha section encountered first → alpha-later stays before beta-earlier.
    #expect(tasks.map(\.id.nativeID) == ["alpha-later", "beta-earlier"])
  }

  @Test func crossProviderSortsAcrossSectionBoundaries() async {
    let list = TaskList(id: "l1", providerID: "p", name: "L1")
    let earlier = Date(timeIntervalSinceNow: -7200)
    let later = Date(timeIntervalSinceNow: -3600)
    let registry = makeRegistry(items: [
      makeScopeItem(
        nativeID: "alpha-later", title: "A", dueDate: later, list: list, section: "Alpha"),
      makeScopeItem(
        nativeID: "beta-earlier", title: "B", dueDate: earlier, list: list, section: "Beta"),
    ])

    let (tasks, _) = await registry.tasks(
      query: .crossProvider(filter: .dueUpToToday),
      sortBy: .dueDate, direction: .ascending)
    // Flat sort ignores section encounter order — beta-earlier has an earlier date.
    #expect(tasks.map(\.id.nativeID) == ["beta-earlier", "alpha-later"])
  }

  @Test func crossProviderTitleFilterSortsAcrossSectionBoundaries() async {
    let list = TaskList(id: "l1", providerID: "p", name: "L1")
    let earlier = Date(timeIntervalSinceNow: -7200)
    let later = Date(timeIntervalSinceNow: -3600)
    let registry = makeRegistry(items: [
      makeScopeItem(
        nativeID: "alpha-later", title: "deploy Alpha", dueDate: later, list: list, section: "Alpha"
      ),
      makeScopeItem(
        nativeID: "beta-earlier", title: "deploy Beta", dueDate: earlier, list: list,
        section: "Beta"),
    ])

    let (tasks, _) = await registry.tasks(
      query: .crossProvider(filter: .titleContains("deploy")),
      sortBy: .dueDate, direction: .ascending)
    #expect(tasks.map(\.id.nativeID) == ["beta-earlier", "alpha-later"])
  }
}
