//
//  TaskProviderTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

// MARK: - Fakes

private final class FakeWritableProvider: WritableTaskProvider {
  let id = "fake-writable"
  let displayName = "Fake Writable"
  let entitlement: ProviderEntitlement = .free

  private(set) var defaultListID: String?
  private(set) var addedDrafts: [TaskDraft] = []
  private(set) var setDefaultListCalls: [String] = []
  private(set) var createListCalls: [String] = []
  private(set) var renameListCalls: [(String, String)] = []
  private(set) var deleteListCalls: [String] = []
  private(set) var deleteTaskCalls: [TaskRef] = []

  func authorize() async throws {}
  func lists() async throws -> [TaskList] {
    [TaskList(id: "list-1", providerID: id, name: "List One")]
  }
  func tasks(in _: TaskList?) async throws -> [TaskItem] { [] }
  func observe() -> AsyncStream<[TaskItem]>? { nil }
  func complete(_: TaskRef) async throws {}
  func reopen(_: TaskRef) async throws {}

  func addTask(_ draft: TaskDraft) -> TaskItem {
    addedDrafts.append(draft)
    return TaskItem(
      id: TaskRef(providerID: id, nativeID: UUID().uuidString),
      title: draft.title,
      notes: nil,
      format: .plainText,
      priority: .none
    )
  }

  func setDefaultList(_ listID: String) {
    setDefaultListCalls.append(listID)
    defaultListID = listID
  }

  @discardableResult
  func createList(name: String) -> TaskList {
    createListCalls.append(name)
    return TaskList(id: UUID().uuidString, providerID: id, name: name)
  }

  func renameList(_ listID: String, name: String) {
    renameListCalls.append((listID, name))
  }

  func deleteList(_ listID: String) {
    deleteListCalls.append(listID)
  }

  func deleteTask(_ ref: TaskRef) {
    deleteTaskCalls.append(ref)
  }
}

private final class FakeReadOnlyProvider: TaskProvider {
  let id = "fake-readonly"
  let displayName = "Fake Read-Only"
  let entitlement: ProviderEntitlement = .free

  func authorize() async throws {}
  func lists() async throws -> [TaskList] { [] }
  func tasks(in _: TaskList?) async throws -> [TaskItem] { [] }
  func observe() -> AsyncStream<[TaskItem]>? { nil }
}

private final class FakeClosableProvider: ClosableTaskProvider {
  let id = "fake-closable"
  let displayName = "Fake Closable"
  let entitlement: ProviderEntitlement = .paid(productID: "com.taskmato.provider.fake")

  private(set) var completedRefs: [TaskRef] = []
  private(set) var reopenedRefs: [TaskRef] = []

  func authorize() async throws {}
  func lists() async throws -> [TaskList] { [] }
  func tasks(in _: TaskList?) async throws -> [TaskItem] { [] }
  func observe() -> AsyncStream<[TaskItem]>? { nil }

  func complete(_ ref: TaskRef) async throws { completedRefs.append(ref) }
  func reopen(_ ref: TaskRef) async throws { reopenedRefs.append(ref) }
}

// MARK: - WritableTaskProvider tests

@Suite("WritableTaskProvider")
struct WritableTaskProviderTests {

  @Test func writableProviderSatisfiesClosableProvider() {
    let provider: any ClosableTaskProvider = FakeWritableProvider()
    #expect(provider.id == "fake-writable")
  }

  @Test func writableProviderSatisfiesTaskProvider() {
    let provider: any TaskProvider = FakeWritableProvider()
    #expect(provider.id == "fake-writable")
  }

  @Test func defaultListIDIsNilInitially() {
    #expect(FakeWritableProvider().defaultListID == nil)
  }

  @Test func addTaskRecordsDraftAndReturnsItem() async throws {
    let provider = FakeWritableProvider()
    var draft = TaskDraft()
    draft.title = "New task"
    let item = try await provider.addTask(draft)
    #expect(provider.addedDrafts.count == 1)
    #expect(item.id.providerID == "fake-writable")
  }

  @Test func setDefaultListPersistsID() async throws {
    let provider = FakeWritableProvider()
    try await provider.setDefaultList("list-1")
    #expect(provider.defaultListID == "list-1")
    #expect(provider.setDefaultListCalls == ["list-1"])
  }

  @Test func createListReturnsTaskListWithCorrectProvider() async throws {
    let provider = FakeWritableProvider()
    let list = try await provider.createList(name: "Work")
    #expect(list.name == "Work")
    #expect(list.providerID == "fake-writable")
    #expect(provider.createListCalls == ["Work"])
  }

  @Test func renameListRecordsCall() async throws {
    let provider = FakeWritableProvider()
    try await provider.renameList("list-1", name: "Personal")
    #expect(provider.renameListCalls.count == 1)
    #expect(provider.renameListCalls[0].0 == "list-1")
    #expect(provider.renameListCalls[0].1 == "Personal")
  }

  @Test func deleteListRecordsCall() async throws {
    let provider = FakeWritableProvider()
    try await provider.deleteList("list-1")
    #expect(provider.deleteListCalls == ["list-1"])
  }

  @Test @MainActor func localProviderConformsToWritableTaskProvider() {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString + ".json")
    let provider: any WritableTaskProvider = LocalProvider(fileURL: url)
    #expect(provider.id == LocalProvider.providerID)
  }
}

// MARK: - Tests

@Suite("ProviderEntitlement")
struct ProviderEntitlementTests {

  @Test func freeIsEqualToFree() {
    #expect(ProviderEntitlement.free == .free)
  }

  @Test func paidMatchesSameProductID() {
    #expect(ProviderEntitlement.paid(productID: "com.x") == .paid(productID: "com.x"))
  }

  @Test func paidDiffersOnProductID() {
    #expect(ProviderEntitlement.paid(productID: "com.x") != .paid(productID: "com.y"))
  }

  @Test func freeDiffersFromPaid() {
    #expect(ProviderEntitlement.free != .paid(productID: "com.x"))
  }
}

@Suite("TaskProvider")
struct TaskProviderTests {

  @Test func readOnlyProviderProperties() {
    let provider = FakeReadOnlyProvider()
    #expect(provider.id == "fake-readonly")
    #expect(provider.displayName == "Fake Read-Only")
    #expect(provider.entitlement == .free)
  }

  @Test func readOnlyProviderObserveReturnsNil() {
    let provider = FakeReadOnlyProvider()
    #expect(provider.observe() == nil)
  }

  @Test func readOnlyProviderListsAndTasksReturnEmpty() async throws {
    let provider = FakeReadOnlyProvider()
    #expect(try await provider.lists().isEmpty)
    #expect(try await provider.tasks(in: nil).isEmpty)
  }

  @Test func closableProviderIsPaid() {
    let provider = FakeClosableProvider()
    #expect(provider.entitlement == .paid(productID: "com.taskmato.provider.fake"))
  }

  @Test func closableProviderTracksComplete() async throws {
    let provider = FakeClosableProvider()
    let ref = TaskRef(providerID: "fake-closable", nativeID: "1")
    try await provider.complete(ref)
    #expect(provider.completedRefs == [ref])
    #expect(provider.reopenedRefs.isEmpty)
  }

  @Test func closableProviderTracksReopen() async throws {
    let provider = FakeClosableProvider()
    let ref = TaskRef(providerID: "fake-closable", nativeID: "1")
    try await provider.reopen(ref)
    #expect(provider.reopenedRefs == [ref])
    #expect(provider.completedRefs.isEmpty)
  }

  @Test func closableProviderSatisfiesTaskProvider() {
    let provider: any TaskProvider = FakeClosableProvider()
    #expect(provider.id == "fake-closable")
  }
}
