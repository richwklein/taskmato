//
//  ProviderRegistryTests.swift
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
  let icon: String = "square"
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

private final class StubWritableProvider: WritableTaskProvider {
  let id: String
  let displayName: String
  let icon: String = "square"
  let entitlement: ProviderEntitlement = .free
  private(set) var defaultListID: String?

  init(id: String) {
    self.id = id
    self.displayName = id
  }

  func authorize() async throws {}
  func lists() async throws -> [TaskList] { [] }
  func tasks(in _: TaskList?) async throws -> [TaskItem] { [] }
  func observe() -> AsyncStream<[TaskItem]>? { nil }
  func complete(_: TaskRef) async throws {}
  func reopen(_: TaskRef) async throws {}

  @discardableResult
  func addTask(_: TaskDraft) async throws -> TaskItem {
    TaskItem(
      id: TaskRef(providerID: id, nativeID: UUID().uuidString),
      title: "", notes: nil, format: .plainText, priority: .none)
  }

  func setDefaultList(_ listID: String) async throws { defaultListID = listID }

  @discardableResult
  func createList(name: String) async throws -> TaskList {
    TaskList(id: UUID().uuidString, providerID: id, name: name)
  }

  func renameList(_: String, name _: String) async throws {}
  func deleteList(_: String) async throws {}
  func updateTask(_: TaskRef, draft _: TaskDraft) async throws {}
  func deleteTask(_: TaskRef) async throws {}
}

private final class StubUnauthorizedProvider: TaskProvider {
  let id: String
  let displayName: String
  let icon: String = "square"
  let entitlement: ProviderEntitlement = .free
  let isAuthorized = false

  init(id: String) {
    self.id = id
    self.displayName = id
  }

  func authorize() async throws {}
  func lists() async throws -> [TaskList] { [] }
  func tasks(in _: TaskList?) async throws -> [TaskItem] { [] }
  func observe() -> AsyncStream<[TaskItem]>? { nil }
}

private final class StubClosableProvider: ClosableTaskProvider {
  let id: String
  let displayName: String
  let icon: String = "square"
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

// MARK: - Tests

@Suite("ProviderRegistry")
@MainActor
struct ProviderRegistryTests {

  private func makeRegistry() -> ProviderRegistry {
    ProviderRegistry(defaults: UserDefaults(suiteName: UUID().uuidString)!)
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

  @Test func closableProviderForClosableConformer() {
    let registry = makeRegistry()
    let provider = StubClosableProvider(id: "closable")
    registry.register(provider)

    let ref = TaskRef(providerID: "closable", nativeID: "x")
    #expect(registry.closableProvider(for: ref) != nil)
  }

  @Test func closableProviderForReadOnlyReturnsNil() {
    let registry = makeRegistry()
    let provider = StubProvider(id: "readonly")
    registry.register(provider)

    let ref = TaskRef(providerID: "readonly", nativeID: "x")
    #expect(registry.closableProvider(for: ref) == nil)
  }

  // MARK: firstEnabledWritableProvider

  @Test func firstEnabledWritableProviderNilWhenNoneRegistered() {
    let registry = makeRegistry()
    #expect(registry.firstEnabledWritableProvider == nil)
  }

  @Test func firstEnabledWritableProviderNilWhenNotEnabled() {
    let registry = makeRegistry()
    let provider = StubWritableProvider(id: "writable")
    registry.register(provider)
    #expect(registry.firstEnabledWritableProvider == nil)
  }

  @Test func firstEnabledWritableProviderReturnsWhenEnabled() {
    let registry = makeRegistry()
    let provider = StubWritableProvider(id: "writable")
    registry.register(provider)
    registry.enable(provider)
    #expect(registry.firstEnabledWritableProvider?.id == "writable")
  }

  // MARK: enabledWritableProvider

  @Test func enabledWritableProviderReturnsExactEnabledWritableProvider() {
    let registry = makeRegistry()
    let provider = StubWritableProvider(id: "writable")
    registry.register(provider)
    registry.enable(provider)
    #expect(registry.enabledWritableProvider(id: "writable")?.id == "writable")
  }

  @Test func enabledWritableProviderReturnsNilForDisabledProvider() {
    let registry = makeRegistry()
    let provider = StubWritableProvider(id: "writable")
    registry.register(provider)
    #expect(registry.enabledWritableProvider(id: "writable") == nil)
  }

  @Test func enabledWritableProviderReturnsNilForReadOnlyProvider() {
    let registry = makeRegistry()
    let provider = StubProvider(id: "read-only")
    registry.register(provider)
    registry.enable(provider)
    #expect(registry.enabledWritableProvider(id: "read-only") == nil)
  }

  // MARK: resolveDefaultWritableProvider

  @Test func resolveDefaultWritableProviderNilIDFallsBackToFirst() {
    let registry = makeRegistry()
    let provider = StubWritableProvider(id: "writable")
    registry.register(provider)
    registry.enable(provider)
    #expect(registry.resolveDefaultWritableProvider(preferredID: nil)?.id == "writable")
  }

  @Test func resolveDefaultWritableProviderNilIDReturnsNilWhenNoneRegistered() {
    let registry = makeRegistry()
    #expect(registry.resolveDefaultWritableProvider(preferredID: nil) == nil)
  }

  @Test func resolveDefaultWritableProviderReturnsPreferredWhenEnabled() {
    let registry = makeRegistry()
    let first = StubWritableProvider(id: "first")
    let second = StubWritableProvider(id: "second")
    registry.register(first)
    registry.register(second)
    registry.enable(first)
    registry.enable(second)
    #expect(registry.resolveDefaultWritableProvider(preferredID: "second")?.id == "second")
  }

  @Test func resolveDefaultWritableProviderFallsBackWhenPreferredIsDisabled() {
    let registry = makeRegistry()
    let first = StubWritableProvider(id: "first")
    let second = StubWritableProvider(id: "second")
    registry.register(first)
    registry.register(second)
    registry.enable(first)
    // "second" is registered but not enabled
    #expect(registry.resolveDefaultWritableProvider(preferredID: "second")?.id == "first")
  }

  @Test func resolveDefaultWritableProviderFallsBackWhenPreferredIsReadOnly() {
    let registry = makeRegistry()
    let readOnly = StubProvider(id: "read-only")
    let writable = StubWritableProvider(id: "writable")
    registry.register(readOnly)
    registry.register(writable)
    registry.enable(readOnly)
    registry.enable(writable)
    #expect(registry.resolveDefaultWritableProvider(preferredID: "read-only")?.id == "writable")
  }

  @Test func resolveDefaultWritableProviderFallsBackWhenPreferredIsUnknown() {
    let registry = makeRegistry()
    let provider = StubWritableProvider(id: "writable")
    registry.register(provider)
    registry.enable(provider)
    #expect(registry.resolveDefaultWritableProvider(preferredID: "ghost")?.id == "writable")
  }

  // MARK: Provider ordering

  @Test func registerSortsProvidersByDisplayOrder() {
    let registry = makeRegistry()
    let high = StubProvider(id: "high")
    let low = StubProvider(id: "low")
    // Simulate displayOrder: register high-order provider first.
    registry.register(high)
    registry.register(low)
    // Both stubs use the default displayOrder (Int.max) so they fall back to displayName order.
    // "high" < "low" alphabetically, so "high" should appear first.
    #expect(registry.providers[0].id == "high")
    #expect(registry.providers[1].id == "low")
  }

  @Test func localProviderDisplayOrderIsLowerThanDefault() {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString + ".json")
    let local = LocalProvider(fileURL: url)
    let readOnly = StubProvider(id: "z-other")
    let registry = makeRegistry()
    registry.register(readOnly)
    registry.register(local)
    #expect(registry.providers[0].id == LocalProvider.providerID)
    #expect(registry.providers[1].id == "z-other")
  }

  @Test func alphaNumericTieBreakOrdersProvidersByDisplayName() {
    let registry = makeRegistry()
    registry.register(StubProvider(id: "zebra"))
    registry.register(StubProvider(id: "apple"))
    registry.register(StubProvider(id: "mango"))
    let ids = registry.providers.map(\.id)
    #expect(ids == ["apple", "mango", "zebra"])
  }

  // MARK: providerAuthorizationStates

  @Test func providerAuthorizationStatesEmptyWithNoProviders() {
    let registry = makeRegistry()
    #expect(registry.providerAuthorizationStates.isEmpty)
  }

  @Test func providerAuthorizationStatesAllTrueByDefault() {
    let registry = makeRegistry()
    registry.register(StubProvider(id: "a"))
    registry.register(StubProvider(id: "b"))
    #expect(registry.providerAuthorizationStates == [true, true])
  }

  @Test func providerAuthorizationStatesReflectsFalse() {
    let registry = makeRegistry()
    registry.register(StubProvider(id: "authorized"))
    registry.register(StubUnauthorizedProvider(id: "unauthorized"))
    #expect(registry.providerAuthorizationStates == [true, false])
  }

}
