//
//  SelectionStoreTests.swift
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

// MARK: - Tests

@Suite("SelectionStore")
@MainActor
struct SelectionStoreTests {

  /// Builds a registry and its selection store over shared `defaults`, wiring the
  /// `onProviderStateChanged` hook exactly as the composition root does so that
  /// `setLists`/`disable` re-validate the selection.
  private func makeStore(defaults: UserDefaults? = nil) -> (
    registry: ProviderRegistry, store: SelectionStore
  ) {
    let defaults = defaults ?? UserDefaults(suiteName: UUID().uuidString)!
    let registry = ProviderRegistry(defaults: defaults)
    let store = SelectionStore(registry: registry, defaults: defaults)
    registry.onProviderStateChanged = { [weak store] in store?.validateSelection() }
    return (registry, store)
  }

  // MARK: - Default selection

  @Test func selectionDefaultsTodayOnFirstLaunch() {
    let (_, store) = makeStore()
    #expect(store.selection == .today)
  }

  // MARK: - Persistence

  @Test func selectionPersistsAcrossReloadForToday() {
    let defaults = UserDefaults(suiteName: UUID().uuidString)!
    let (_, first) = makeStore(defaults: defaults)
    first.select(.today)
    let (_, second) = makeStore(defaults: defaults)
    #expect(second.selection == .today)
  }

  @Test func selectionPersistsAcrossReloadForList() {
    let defaults = UserDefaults(suiteName: UUID().uuidString)!
    let target = SidebarSelection.list(SelectedList(providerID: "alpha", listID: "list-1"))
    let (_, first) = makeStore(defaults: defaults)
    first.select(target)
    let (_, second) = makeStore(defaults: defaults)
    #expect(second.selection == target)
  }

  // MARK: - providerLists cache

  @Test func setListsPopulatesProviderListsCache() {
    let (registry, _) = makeStore()
    let lists = [
      TaskList(id: "a", providerID: "alpha", name: "A"),
      TaskList(id: "b", providerID: "alpha", name: "B"),
    ]
    registry.setLists(lists, forProviderID: "alpha")
    #expect(registry.providerLists["alpha"]?.count == 2)
  }

  @Test func disableProviderClearsItsListsCache() {
    let (registry, _) = makeStore()
    let provider = SelectionStubProvider(id: "alpha")
    registry.register(provider)
    registry.enable(provider)
    registry.setLists([TaskList(id: "a", providerID: "alpha", name: "A")], forProviderID: "alpha")
    registry.disable(providerID: "alpha")
    #expect(registry.providerLists["alpha"] == nil)
  }

  // MARK: - validateSelection

  @Test func todaySelectionIsAlwaysValid() {
    let (registry, store) = makeStore()
    let provider = SelectionStubProvider(id: "alpha")
    registry.register(provider)
    registry.enable(provider)
    store.select(.today)
    // With no lists loaded, validateSelection should still leave Today unchanged.
    store.validateSelection()
    #expect(store.selection == .today)
  }

  @Test func setListsTriggersValidationAndLeavesTodayUnchanged() {
    let (registry, store) = makeStore()
    let provider = SelectionStubProvider(id: "alpha")
    registry.register(provider)
    registry.enable(provider)
    // Selection is .today by default; setLists fires the hook into validateSelection.
    registry.setLists([TaskList(id: "a", providerID: "alpha", name: "A")], forProviderID: "alpha")
    #expect(store.selection == .today)
  }

  @Test func validateSelectionDropsUnknownProvider() {
    let (_, store) = makeStore()
    let staleSelection = SidebarSelection.list(
      SelectedList(providerID: "unknown-provider", listID: "list-1"))
    store.select(staleSelection)
    store.validateSelection()
    #expect(store.selection == .today)
  }

  @Test func validateSelectionDropsUnknownListID() {
    let (registry, store) = makeStore()
    let provider = SelectionStubProvider(id: "alpha")
    registry.register(provider)
    registry.enable(provider)
    store.select(.list(SelectedList(providerID: "alpha", listID: "missing-list")))
    // Populate cache with a different list ID; the hook re-validates.
    registry.setLists(
      [TaskList(id: "other", providerID: "alpha", name: "Other")], forProviderID: "alpha")
    #expect(store.selection == .list(SelectedList(providerID: "alpha", listID: "other")))
  }

  @Test func validateSelectionFallsBackToWritableDefaultList() {
    let (registry, store) = makeStore()
    let writable = SelectionWritableProvider(id: "local", defaultListID: "inbox")
    registry.register(writable)
    registry.enable(writable)
    // Populate the writable provider's lists in cache.
    let inboxList = TaskList(id: "inbox", providerID: "local", name: "Inbox")
    registry.setLists([inboxList], forProviderID: "local")
    // Now select a nonexistent list elsewhere.
    store.select(.list(SelectedList(providerID: "ghost", listID: "gone")))
    store.validateSelection()
    #expect(store.selection == .list(SelectedList(providerID: "local", listID: "inbox")))
  }

  @Test func validateSelectionFallsBackToTodayWhenNoListsAvailable() {
    let (registry, store) = makeStore()
    let provider = SelectionStubProvider(id: "alpha")
    registry.register(provider)
    registry.enable(provider)
    store.select(.list(SelectedList(providerID: "alpha", listID: "old-list")))
    // Populate cache with an empty list array; the hook re-validates.
    registry.setLists([], forProviderID: "alpha")
    #expect(store.selection == .today)
  }

  // MARK: - Legacy key cleanup

  @Test func legacyScopeKeysAreRemovedOnInit() {
    let defaults = UserDefaults(suiteName: UUID().uuidString)!
    // Write dummy blobs for both legacy keys.
    defaults.set(Data([1, 2, 3]), forKey: "taskRegistry.providerListScopes")
    defaults.set(Data([4, 5, 6]), forKey: "taskRegistry.selectedList")
    // The registry clears the list-scope key; the selection store clears the selected-list key.
    let registry = ProviderRegistry(defaults: defaults)
    _ = SelectionStore(registry: registry, defaults: defaults)
    #expect(defaults.data(forKey: "taskRegistry.providerListScopes") == nil)
    #expect(defaults.data(forKey: "taskRegistry.selectedList") == nil)
  }
}
