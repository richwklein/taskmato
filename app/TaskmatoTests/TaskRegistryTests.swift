//
//  TaskRegistryTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

// MARK: - Fakes

private struct StubError: Error, Equatable {}

private final class StubProvider: TaskProvider {
  let id: String
  let displayName: String
  let entitlement: ProviderEntitlement = .free
  let stubbedTasks: [TaskItem]
  let shouldThrow: Bool

  init(id: String, tasks: [TaskItem] = [], shouldThrow: Bool = false) {
    self.id = id
    self.displayName = id
    self.stubbedTasks = tasks
    self.shouldThrow = shouldThrow
  }

  func authorize() async throws {}
  func lists() async throws -> [TaskList] { [] }
  func tasks(in _: TaskList?) async throws -> [TaskItem] {
    if shouldThrow { throw StubError() }
    return stubbedTasks
  }
  func observe() -> AsyncStream<[TaskItem]>? { nil }
}

private final class StubMutableProvider: MutableTaskProvider {
  let id: String
  let displayName: String
  let entitlement: ProviderEntitlement = .free
  let stubbedTasks: [TaskItem]
  private(set) var completedRefs: [TaskRef] = []

  init(id: String, tasks: [TaskItem] = []) {
    self.id = id
    self.displayName = id
    self.stubbedTasks = tasks
  }

  func authorize() async throws {}
  func lists() async throws -> [TaskList] { [] }
  func tasks(in _: TaskList?) async throws -> [TaskItem] { stubbedTasks }
  func observe() -> AsyncStream<[TaskItem]>? { nil }
  func complete(_ ref: TaskRef) async throws { completedRefs.append(ref) }
  func reopen(_: TaskRef) async throws {}
}

private func makeItem(
  providerID: String,
  nativeID: String,
  title: String,
  priority: TaskPriority = .none,
  dueDate: Date? = nil
) -> TaskItem {
  TaskItem(
    id: TaskRef(providerID: providerID, nativeID: nativeID),
    title: title,
    notes: nil,
    notesFormat: .plainText,
    priority: priority,
    dueDate: dueDate,
    scheduledDate: nil,
    startDate: nil,
    list: nil,
    section: nil,
    sourceURL: nil
  )
}

// MARK: - Tests

@Suite("TaskRegistry")
@MainActor
struct TaskRegistryTests {

  private func makeRegistry() -> TaskRegistry {
    TaskRegistry(defaults: UserDefaults(suiteName: UUID().uuidString)!)
  }

  // MARK: Registration

  @Test func registerAddsProvider() {
    let registry = makeRegistry()
    let provider = StubProvider(id: "alpha")
    registry.register(provider)
    #expect(registry.providers.count == 1)
  }

  @Test func registerIgnoresDuplicateID() {
    let registry = makeRegistry()
    registry.register(StubProvider(id: "alpha"))
    registry.register(StubProvider(id: "alpha"))
    #expect(registry.providers.count == 1)
  }

  // MARK: Enable / Disable

  @Test func enableMarksProviderEnabled() {
    let registry = makeRegistry()
    let provider = StubProvider(id: "alpha")
    registry.register(provider)
    registry.enable(provider)
    #expect(registry.isEnabled("alpha"))
  }

  @Test func disableMarksProviderDisabled() {
    let registry = makeRegistry()
    let provider = StubProvider(id: "alpha")
    registry.register(provider)
    registry.enable(provider)
    registry.disable(providerID: "alpha")
    #expect(!registry.isEnabled("alpha"))
  }

  @Test func newProviderIsNotEnabledByDefault() {
    let registry = makeRegistry()
    let provider = StubProvider(id: "alpha")
    registry.register(provider)
    #expect(!registry.isEnabled("alpha"))
  }

  // MARK: Fan-out

  @Test func tasksAcrossTwoProviders() async {
    let registry = makeRegistry()
    let alpha = StubProvider(
      id: "alpha", tasks: [makeItem(providerID: "alpha", nativeID: "1", title: "Alpha task")])
    let beta = StubProvider(
      id: "beta", tasks: [makeItem(providerID: "beta", nativeID: "2", title: "Beta task")])
    registry.register(alpha)
    registry.register(beta)
    registry.enable(alpha)
    registry.enable(beta)

    let (tasks, errors) = await registry.tasks(matching: "")
    #expect(tasks.count == 2)
    #expect(errors.isEmpty)
  }

  @Test func disabledProviderExcludedFromFanOut() async {
    let registry = makeRegistry()
    let alpha = StubProvider(
      id: "alpha", tasks: [makeItem(providerID: "alpha", nativeID: "1", title: "Alpha task")])
    let beta = StubProvider(
      id: "beta", tasks: [makeItem(providerID: "beta", nativeID: "2", title: "Beta task")])
    registry.register(alpha)
    registry.register(beta)
    registry.enable(alpha)

    let (tasks, errors) = await registry.tasks(matching: "")
    #expect(tasks.count == 1)
    #expect(tasks[0].id.providerID == "alpha")
    #expect(errors.isEmpty)
  }

  @Test func taskSearchFiltersOnTitle() async {
    let registry = makeRegistry()
    let provider = StubProvider(
      id: "alpha",
      tasks: [
        makeItem(providerID: "alpha", nativeID: "1", title: "Write tests"),
        makeItem(providerID: "alpha", nativeID: "2", title: "Review PR"),
      ])
    registry.register(provider)
    registry.enable(provider)

    let (tasks, errors) = await registry.tasks(matching: "write")
    #expect(tasks.count == 1)
    #expect(tasks[0].title == "Write tests")
    #expect(errors.isEmpty)
  }

  @Test func tasksSortedByPriorityDescending() async {
    let registry = makeRegistry()
    let provider = StubProvider(
      id: "alpha",
      tasks: [
        makeItem(providerID: "alpha", nativeID: "1", title: "Low", priority: .low),
        makeItem(providerID: "alpha", nativeID: "2", title: "High", priority: .high),
        makeItem(providerID: "alpha", nativeID: "3", title: "Medium", priority: .medium),
      ])
    registry.register(provider)
    registry.enable(provider)

    let (tasks, _) = await registry.tasks(matching: "")
    #expect(tasks.map(\.title) == ["High", "Medium", "Low"])
  }

  @Test func samePriorityTasksSortedByDueDateAscending() async {
    let registry = makeRegistry()
    let earlier = Date(timeIntervalSince1970: 1_000)
    let later = Date(timeIntervalSince1970: 2_000)
    let provider = StubProvider(
      id: "alpha",
      tasks: [
        makeItem(providerID: "alpha", nativeID: "1", title: "Later", dueDate: later),
        makeItem(providerID: "alpha", nativeID: "2", title: "Earlier", dueDate: earlier),
      ])
    registry.register(provider)
    registry.enable(provider)

    let (tasks, _) = await registry.tasks(matching: "")
    #expect(tasks.map(\.title) == ["Earlier", "Later"])
  }

  @Test func failingProviderErrorSurfacedOtherTasksReturned() async {
    let registry = makeRegistry()
    let good = StubProvider(
      id: "good", tasks: [makeItem(providerID: "good", nativeID: "1", title: "Good task")])
    let bad = StubProvider(id: "bad", shouldThrow: true)
    registry.register(good)
    registry.register(bad)
    registry.enable(good)
    registry.enable(bad)

    let (tasks, errors) = await registry.tasks(matching: "")
    #expect(tasks.count == 1)
    #expect(tasks[0].id.providerID == "good")
    #expect(errors.count == 1)
    #expect(errors[0].providerID == "bad")
    #expect(errors[0].error is StubError)
  }

  // MARK: Provider lookup

  @Test func providerForRefReturnsCorrectProvider() {
    let registry = makeRegistry()
    let provider = StubProvider(id: "alpha")
    registry.register(provider)

    let ref = TaskRef(providerID: "alpha", nativeID: "x")
    #expect(registry.provider(for: ref)?.id == "alpha")
  }

  @Test func providerForUnknownRefReturnsNil() {
    let registry = makeRegistry()
    let ref = TaskRef(providerID: "unknown", nativeID: "x")
    #expect(registry.provider(for: ref) == nil)
  }

  @Test func mutableProviderForMutableConformer() {
    let registry = makeRegistry()
    let provider = StubMutableProvider(id: "mutable")
    registry.register(provider)

    let ref = TaskRef(providerID: "mutable", nativeID: "x")
    #expect(registry.mutableProvider(for: ref) != nil)
  }

  @Test func mutableProviderForReadOnlyReturnsNil() {
    let registry = makeRegistry()
    let provider = StubProvider(id: "readonly")
    registry.register(provider)

    let ref = TaskRef(providerID: "readonly", nativeID: "x")
    #expect(registry.mutableProvider(for: ref) == nil)
  }
}
