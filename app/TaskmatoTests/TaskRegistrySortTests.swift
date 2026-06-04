//
//  TaskRegistrySortTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

// MARK: - Fakes

private final class SortStubProvider: TaskProvider {
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

private func makeSortItem(
  providerID: String = "p",
  nativeID: String,
  title: String,
  priority: TaskPriority = .none,
  dueDate: Date? = nil,
  createdAt: Date? = nil,
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
    createdAt: createdAt
  )
}

// MARK: - Tests

@Suite("TaskRegistry sort")
@MainActor
struct TaskRegistrySortTests {

  private func makeRegistry(items: [TaskItem]) -> TaskRegistry {
    let registry = TaskRegistry(defaults: UserDefaults(suiteName: UUID().uuidString)!)
    let provider = SortStubProvider(id: "p", items: items)
    registry.register(provider)
    registry.enable(provider)
    return registry
  }

  // MARK: - Due Date

  @Test func sortByDueDateAscendingPutsNilLast() async {
    let near = Date(timeIntervalSinceNow: 3600)
    let far = Date(timeIntervalSinceNow: 7200)
    let items = [
      makeSortItem(nativeID: "nil", title: "No Due"),
      makeSortItem(nativeID: "far", title: "Far", dueDate: far),
      makeSortItem(nativeID: "near", title: "Near", dueDate: near),
    ]
    let registry = makeRegistry(items: items)
    let (tasks, _) = await registry.tasks(
      matching: "", selection: nil, sortBy: .dueDate, direction: .ascending)
    #expect(tasks.map(\.id.nativeID) == ["near", "far", "nil"])
  }

  @Test func sortByDueDateDescendingPutsNilLast() async {
    let near = Date(timeIntervalSinceNow: 3600)
    let far = Date(timeIntervalSinceNow: 7200)
    let items = [
      makeSortItem(nativeID: "near", title: "Near", dueDate: near),
      makeSortItem(nativeID: "nil", title: "No Due"),
      makeSortItem(nativeID: "far", title: "Far", dueDate: far),
    ]
    let registry = makeRegistry(items: items)
    let (tasks, _) = await registry.tasks(
      matching: "", selection: nil, sortBy: .dueDate, direction: .descending)
    #expect(tasks.map(\.id.nativeID) == ["far", "near", "nil"])
  }

  // MARK: - Priority

  @Test func sortByPriorityDescendingMatchesLegacyBehavior() async {
    let near = Date(timeIntervalSinceNow: 3600)
    let far = Date(timeIntervalSinceNow: 7200)
    let items = [
      makeSortItem(nativeID: "low-nil", title: "A", priority: .low, dueDate: nil),
      makeSortItem(nativeID: "high-near", title: "B", priority: .high, dueDate: near),
      makeSortItem(nativeID: "high-far", title: "C", priority: .high, dueDate: far),
      makeSortItem(nativeID: "none-near", title: "D", priority: .none, dueDate: near),
    ]
    let registry = makeRegistry(items: items)
    let (tasks, _) = await registry.tasks(
      matching: "", selection: nil, sortBy: .priority, direction: .descending)
    // high priority first, tie-broken by dueDate asc (nil last); then lower priorities
    #expect(tasks.map(\.id.nativeID) == ["high-near", "high-far", "low-nil", "none-near"])
  }

  @Test func sortByPriorityAscendingReversesPriority() async {
    let items = [
      makeSortItem(nativeID: "high", title: "B", priority: .high),
      makeSortItem(nativeID: "none", title: "A", priority: .none),
      makeSortItem(nativeID: "low", title: "C", priority: .low),
    ]
    let registry = makeRegistry(items: items)
    let (tasks, _) = await registry.tasks(
      matching: "", selection: nil, sortBy: .priority, direction: .ascending)
    #expect(tasks.map(\.id.nativeID) == ["none", "low", "high"])
  }

  // MARK: - Title

  @Test func sortByTitleUsesLocalizedStandardCompare() async {
    let items = [
      makeSortItem(nativeID: "10", title: "Item 10"),
      makeSortItem(nativeID: "2", title: "Item 2"),
      makeSortItem(nativeID: "1", title: "Item 1"),
    ]
    let registry = makeRegistry(items: items)
    let (tasks, _) = await registry.tasks(
      matching: "", selection: nil, sortBy: .title, direction: .ascending)
    // localizedStandardCompare treats "Item 2" < "Item 10" (numeric ordering)
    #expect(tasks.map(\.id.nativeID) == ["1", "2", "10"])
  }

  // MARK: - Creation Date

  @Test func sortByCreationDateAscendingPutsNilLast() async {
    let earlier = Date(timeIntervalSinceNow: -7200)
    let later = Date(timeIntervalSinceNow: -3600)
    let items = [
      makeSortItem(nativeID: "nil", title: "No Date"),
      makeSortItem(nativeID: "later", title: "Later", createdAt: later),
      makeSortItem(nativeID: "earlier", title: "Earlier", createdAt: earlier),
    ]
    let registry = makeRegistry(items: items)
    let (tasks, _) = await registry.tasks(
      matching: "", selection: nil, sortBy: .creationDate, direction: .ascending)
    #expect(tasks.map(\.id.nativeID) == ["earlier", "later", "nil"])
  }

  // MARK: - Tiebreaker

  @Test func sortIsDeterministicForEqualKeys() async {
    let sameDate = Date(timeIntervalSinceNow: 3600)
    let items = [
      makeSortItem(nativeID: "z", title: "Same Title", dueDate: sameDate),
      makeSortItem(nativeID: "a", title: "Same Title", dueDate: sameDate),
      makeSortItem(nativeID: "m", title: "Same Title", dueDate: sameDate),
    ]
    let registry = makeRegistry(items: items)
    let (tasks, _) = await registry.tasks(
      matching: "", selection: nil, sortBy: .dueDate, direction: .ascending)
    // All share the same dueDate and title; TaskRef (providerID/nativeID) is the final tiebreaker.
    // All have providerID "p", so nativeID order: "a" < "m" < "z".
    #expect(tasks.map(\.id.nativeID) == ["a", "m", "z"])
  }

  // MARK: - Section order

  @Test func sortAppliesWithinSectionsNotAcrossThem() async {
    let list = TaskList(id: "list1", providerID: "p", name: "List 1")
    let items = [
      makeSortItem(nativeID: "alpha-c", title: "C", list: list, section: "Alpha"),
      makeSortItem(nativeID: "alpha-a", title: "A", list: list, section: "Alpha"),
      makeSortItem(nativeID: "beta-d", title: "D", list: list, section: "Beta"),
      makeSortItem(nativeID: "beta-b", title: "B", list: list, section: "Beta"),
    ]
    let registry = makeRegistry(items: items)
    let (tasks, _) = await registry.tasks(
      matching: "", selection: nil, sortBy: .title, direction: .ascending)
    // Sections maintain provider encounter order (Alpha before Beta).
    // Tasks within each section are sorted by title ascending.
    #expect(tasks.map(\.id.nativeID) == ["alpha-a", "alpha-c", "beta-b", "beta-d"])
  }
}
