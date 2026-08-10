//
//  TaskDestinationResolverTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

private final class ResolverWritableProvider: WritableTaskProvider {
  let id: ProviderID
  let displayName: String
  let icon = "square"
  let entitlement: ProviderEntitlement = .free
  let contentFormat: ContentFormat = .plainText
  var defaultListID: String?
  var availableLists: [TaskList]

  init(
    id: ProviderID, lists: [TaskList], defaultListID: String? = nil
  ) {
    self.id = id
    self.displayName = id.rawValue
    self.availableLists = lists
    self.defaultListID = defaultListID
  }

  func authorize() async throws {}
  func lists() async throws -> [TaskList] { availableLists }
  func tasks(in _: TaskList?) async throws -> [TaskItem] { [] }
  func observe() -> AsyncStream<[TaskItem]>? { nil }
  func complete(_: TaskRef) async throws {}
  func reopen(_: TaskRef) async throws {}

  @discardableResult
  func addTask(_ draft: TaskDraft) async throws -> TaskItem {
    TaskItem(
      id: TaskRef(providerID: id, nativeID: UUID().uuidString), title: draft.title,
      notes: draft.notes, format: contentFormat, priority: draft.priority,
      dueDate: draft.dueDate, dueDateIncludesTime: draft.dueDateIncludesTime,
      scheduledDate: nil, startDate: nil,
      list: availableLists.first { $0.id == draft.listID }, section: draft.section, sourceURL: nil)
  }

  func setDefaultList(_ listID: String) async throws { defaultListID = listID }
  func updateTask(_: TaskRef, draft _: TaskDraft) async throws {}
  func deleteTask(_: TaskRef) async throws {}
}

@MainActor
struct TaskDestinationResolverTests {

  private struct ResolverContext {
    let registry: ProviderRegistry
    let settings: AppSettings
  }

  private func makeContext() -> ResolverContext {
    let defaults = UserDefaults(suiteName: UUID().uuidString)!
    let store = SettingsStore(defaults: defaults)
    return ResolverContext(
      registry: ProviderRegistry(store: store), settings: AppSettings(store: store))
  }

  private func makeList(_ id: String, providerID: ProviderID, name: String? = nil) -> TaskList {
    TaskList(id: id, providerID: providerID, name: name ?? id)
  }

  @Test func explicitProviderAndListWin() async throws {
    let context = makeContext()
    let first = ResolverWritableProvider(
      id: "first", lists: [makeList("first-list", providerID: "first")])
    let second = ResolverWritableProvider(
      id: "second", lists: [makeList("second-list", providerID: "second")])
    context.registry.register(first)
    context.registry.register(second)
    context.registry.enable(first)
    context.registry.enable(second)
    let resolver = TaskDestinationResolver(registry: context.registry, settings: context.settings)

    let destination = try await resolver.resolve(
      providerID: second.id, listID: "second-list",
      sidebarSelection: .list(
        SelectedList(providerID: first.id, listID: "first-list")))

    #expect(destination.provider.id == second.id)
    #expect(destination.listID == "second-list")
  }

  @Test func sidebarProviderAndListAreUsedBeforeSettings() async throws {
    let context = makeContext()
    let sidebarProvider = ResolverWritableProvider(
      id: "sidebar", lists: [makeList("sidebar-list", providerID: "sidebar")])
    let settingsProvider = ResolverWritableProvider(
      id: "settings", lists: [makeList("settings-list", providerID: "settings")])
    context.registry.register(sidebarProvider)
    context.registry.register(settingsProvider)
    context.registry.enable(sidebarProvider)
    context.registry.enable(settingsProvider)
    context.settings.defaultWritableProviderID = settingsProvider.id
    let resolver = TaskDestinationResolver(registry: context.registry, settings: context.settings)

    let destination = try await resolver.resolve(
      sidebarSelection: .list(
        SelectedList(providerID: sidebarProvider.id, listID: "sidebar-list")))

    #expect(destination.provider.id == sidebarProvider.id)
    #expect(destination.listID == "sidebar-list")
  }

  @Test func settingsProviderWinsBeforeProviderOrder() async throws {
    let context = makeContext()
    let first = ResolverWritableProvider(
      id: "first", lists: [makeList("first-list", providerID: "first")])
    let preferred = ResolverWritableProvider(
      id: "preferred", lists: [makeList("preferred-list", providerID: "preferred")])
    context.registry.register(first)
    context.registry.register(preferred)
    context.registry.enable(first)
    context.registry.enable(preferred)
    context.settings.defaultWritableProviderID = preferred.id
    let resolver = TaskDestinationResolver(registry: context.registry, settings: context.settings)

    let destination = try await resolver.resolve()

    #expect(destination.provider.id == preferred.id)
    #expect(destination.listID == "preferred-list")
  }

  @Test func invalidDefaultFallsBackToFirstAvailableList() async throws {
    let context = makeContext()
    let provider = ResolverWritableProvider(
      id: "provider",
      lists: [
        makeList("first", providerID: "provider"), makeList("second", providerID: "provider"),
      ],
      defaultListID: "deleted")
    context.registry.register(provider)
    context.registry.enable(provider)
    let resolver = TaskDestinationResolver(registry: context.registry, settings: context.settings)

    let destination = try await resolver.resolve()

    #expect(destination.listID == "first")
  }

  @Test func listNameUsesCaseInsensitiveMatchAndUnmatchedNameFallsBack() async throws {
    let context = makeContext()
    let provider = ResolverWritableProvider(
      id: "provider", lists: [makeList("work", providerID: "provider", name: "Work")],
      defaultListID: "work")
    context.registry.register(provider)
    context.registry.enable(provider)
    let resolver = TaskDestinationResolver(registry: context.registry, settings: context.settings)

    let matched = try await resolver.resolve(listName: "work")
    let unmatched = try await resolver.resolve(listName: "Missing")

    #expect(matched.listID == "work")
    #expect(unmatched.listID == "work")
  }

  @Test func noWritableProviderThrowsTypedError() async {
    let context = makeContext()
    let resolver = TaskDestinationResolver(registry: context.registry, settings: context.settings)

    await #expect(throws: TaskDestinationResolutionError.noWritableProvider) {
      try await resolver.resolve()
    }
  }

  @Test func noAvailableListThrowsProviderScopedError() async {
    let context = makeContext()
    let provider = ResolverWritableProvider(id: "provider", lists: [])
    context.registry.register(provider)
    context.registry.enable(provider)
    let resolver = TaskDestinationResolver(registry: context.registry, settings: context.settings)

    await #expect(
      throws: TaskDestinationResolutionError.noAvailableList(
        providerID: provider.id, providerName: provider.displayName)
    ) {
      try await resolver.resolve()
    }
  }
}
