//
//  URLSchemeHandlerTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

// MARK: - Test context

private struct HandlerContext {
  let handler: URLSchemeHandler
  let registry: TaskRegistry
  let selectionStore: TaskSelectionStore
  let localProvider: LocalProvider
  let settings: AppSettings
}

// MARK: - Fakes

private final class StubTaskProvider: TaskProvider {
  let id: String
  let displayName: String
  let icon: String = "square"
  let entitlement: ProviderEntitlement = .free
  private let stubbedTasks: [TaskItem]

  init(id: String, tasks: [TaskItem] = []) {
    self.id = id
    self.displayName = id
    self.stubbedTasks = tasks
  }

  nonisolated func authorize() async throws {}
  func lists() async throws -> [TaskList] { [] }
  func tasks(in list: TaskList?) async throws -> [TaskItem] { stubbedTasks }
  func observe() -> AsyncStream<[TaskItem]>? { nil }
}

private final class StubWritableProvider: WritableTaskProvider {
  let id: String
  let displayName: String
  let icon: String = "square"
  let entitlement: ProviderEntitlement = .free
  let defaultListID: String? = nil

  init(id: String) {
    self.id = id
    self.displayName = id
  }

  nonisolated func authorize() async throws {}
  func lists() async throws -> [TaskList] { [] }
  func tasks(in _: TaskList?) async throws -> [TaskItem] { [] }
  func observe() -> AsyncStream<[TaskItem]>? { nil }
  func complete(_: TaskRef) async throws {}
  func reopen(_: TaskRef) async throws {}

  @discardableResult
  func addTask(_ draft: TaskDraft) async throws -> TaskItem {
    TaskItem(
      id: TaskRef(providerID: id, nativeID: UUID().uuidString),
      title: draft.title,
      notes: draft.notes,
      format: .plainText,
      priority: draft.priority,
      dueDate: draft.dueDate,
      scheduledDate: nil,
      startDate: nil,
      list: nil,
      section: nil,
      sourceURL: nil
    )
  }

  func setDefaultList(_: String) async throws {}
  func createList(name: String) async throws -> TaskList {
    TaskList(id: UUID().uuidString, providerID: id, name: name)
  }
  func renameList(_: String, name _: String) async throws {}
  func deleteList(_: String) async throws {}
  func updateTask(_: TaskRef, draft _: TaskDraft) async throws {}
  func deleteTask(_: TaskRef) async throws {}
}

// MARK: - Tests

@MainActor
struct URLSchemeHandlerTests {

  // MARK: - Helpers

  private func makeTempURL() -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("json")
  }

  /// Builds a fully wired handler. Pass `enableLocalProvider: false` to test the transient path.
  private func makeHandler(
    stubProviderTasks: [TaskItem] = [],
    enableLocalProvider: Bool = true,
    defaultWritableProviderID: String? = nil
  ) -> HandlerContext {
    let defaults = UserDefaults(suiteName: UUID().uuidString)!
    let selectionStore = TaskSelectionStore(defaults: defaults)
    let engine = SessionEngine()
    let registry = TaskRegistry(defaults: defaults)
    let localProvider = LocalProvider(fileURL: makeTempURL())
    let settings = AppSettings(defaults: defaults)
    settings.defaultWritableProviderID = defaultWritableProviderID

    registry.register(localProvider)
    if enableLocalProvider {
      registry.enable(localProvider)
    }

    if !stubProviderTasks.isEmpty {
      let stub = StubTaskProvider(id: "stub", tasks: stubProviderTasks)
      registry.register(stub)
      registry.enable(stub)
    }

    let handler = URLSchemeHandler(
      registry: registry,
      selectionStore: selectionStore,
      engine: engine,
      settings: settings,
      nav: MainNavigation(settings: settings)
    )
    return HandlerContext(
      handler: handler,
      registry: registry,
      selectionStore: selectionStore,
      localProvider: localProvider,
      settings: settings
    )
  }

  private func makeTask(title: String, providerID: String = "stub") -> TaskItem {
    TaskItem(
      id: TaskRef(providerID: providerID, nativeID: UUID().uuidString),
      title: title,
      notes: nil,
      format: .plainText,
      priority: .none,
      dueDate: nil,
      scheduledDate: nil,
      startDate: nil,
      list: nil,
      section: nil,
      sourceURL: nil
    )
  }

  // MARK: - Ad-hoc task creation (LocalProvider enabled — default provider)

  @Test func adHocTaskWrittenToLocalProviderWhenEnabled() async throws {
    let ctx = makeHandler(enableLocalProvider: true)
    await ctx.handler.handle(URL(string: "taskmato://start?title=Buy%20groceries")!)
    #expect(ctx.selectionStore.activeTask?.title == "Buy groceries")
    #expect(ctx.selectionStore.activeTask?.id.providerID == LocalProvider.providerID)
    let items = try await ctx.localProvider.tasks(in: nil)
    #expect(items.first?.title == "Buy groceries")
  }

  @Test func adHocTaskMatchesLocalListByName() async throws {
    let ctx = makeHandler(enableLocalProvider: true)
    try await ctx.localProvider.createList(name: "Work")
    await ctx.handler.handle(URL(string: "taskmato://start?title=Meeting&list=Work")!)
    let tasks = try await ctx.localProvider.tasks(in: nil)
    #expect(tasks.first?.list?.name == "Work")
  }

  @Test func adHocTaskFallsBackToDefaultListWhenListNotFound() async throws {
    let ctx = makeHandler(enableLocalProvider: true)
    await ctx.handler.handle(URL(string: "taskmato://start?title=Misc&list=Nonexistent")!)
    let tasks = try await ctx.localProvider.tasks(in: nil)
    #expect(tasks.first?.list != nil)
  }

  // MARK: - Ad-hoc task creation (LocalProvider disabled — transient)

  @Test func adHocTaskIsTransientWhenLocalDisabled() async {
    let ctx = makeHandler(enableLocalProvider: false)
    await ctx.handler.handle(URL(string: "taskmato://start?title=Transient+Task")!)
    #expect(ctx.selectionStore.activeTask?.title == "Transient Task")
    #expect(ctx.selectionStore.activeTask?.id.providerID == "adhoc")
  }

  @Test func adHocTaskWithHighPriority() async {
    let ctx = makeHandler()
    await ctx.handler.handle(URL(string: "taskmato://start?title=Urgent&priority=high")!)
    #expect(ctx.selectionStore.activeTask?.priority == .high)
  }

  @Test func adHocTaskWithDueDate() async {
    let ctx = makeHandler()
    await ctx.handler.handle(URL(string: "taskmato://start?title=Due+Task&due=2026-12-01")!)
    #expect(ctx.selectionStore.activeTask?.dueDate != nil)
  }

  // MARK: - Ad-hoc: URL param provider override

  @Test func adHocTaskURLProviderParamTargetsSpecificProvider() async throws {
    let ctx = makeHandler(enableLocalProvider: true)
    await ctx.handler.handle(
      URL(string: "taskmato://start?title=Override&provider=\(LocalProvider.providerID)")!)
    #expect(ctx.selectionStore.activeTask?.id.providerID == LocalProvider.providerID)
    let items = try await ctx.localProvider.tasks(in: nil)
    #expect(items.map(\.title).contains("Override"))
  }

  @Test func adHocTaskURLProviderParamFallsBackWhenProviderDisabled() async {
    // provider= refers to a disabled/unknown provider → falls back to settings/firstEnabled
    let ctx = makeHandler(enableLocalProvider: true)
    ctx.registry.disable(providerID: LocalProvider.providerID)
    await ctx.handler.handle(
      URL(string: "taskmato://start?title=Fallback&provider=\(LocalProvider.providerID)")!)
    // No enabled writable provider → transient
    #expect(ctx.selectionStore.activeTask?.id.providerID == "adhoc")
  }

  @Test func adHocTaskURLProviderParamFallsBackToSettingsDefaultWhenDisabled() async {
    let ctx = makeHandler(enableLocalProvider: false, defaultWritableProviderID: "zzz-default")
    let first = StubWritableProvider(id: "aaa-first")
    let defaultProvider = StubWritableProvider(id: "zzz-default")
    let disabledTarget = StubWritableProvider(id: "target-disabled")
    ctx.registry.register(first)
    ctx.registry.register(defaultProvider)
    ctx.registry.register(disabledTarget)
    ctx.registry.enable(first)
    ctx.registry.enable(defaultProvider)

    await ctx.handler.handle(
      URL(string: "taskmato://start?title=Fallback&provider=target-disabled")!)

    #expect(ctx.selectionStore.activeTask?.id.providerID == "zzz-default")
  }

  // MARK: - Ad-hoc: settings default writable provider

  @Test func adHocTaskUsesSettingsDefaultProvider() async throws {
    let ctx = makeHandler(
      enableLocalProvider: true,
      defaultWritableProviderID: LocalProvider.providerID
    )
    await ctx.handler.handle(URL(string: "taskmato://start?title=Settings+Task")!)
    #expect(ctx.selectionStore.activeTask?.id.providerID == LocalProvider.providerID)
    let items = try await ctx.localProvider.tasks(in: nil)
    #expect(items.map(\.title).contains("Settings Task"))
  }

  @Test func adHocTaskIgnoresSettingsDefaultWhenProviderDisabled() async {
    let ctx = makeHandler(
      enableLocalProvider: false,
      defaultWritableProviderID: LocalProvider.providerID
    )
    await ctx.handler.handle(URL(string: "taskmato://start?title=No+Provider")!)
    // Settings points at disabled provider → falls through to transient
    #expect(ctx.selectionStore.activeTask?.id.providerID == "adhoc")
  }

  // MARK: - Step 1: Lookup by provider + ID

  @Test func lookupByIDInStubProvider() async {
    let existing = makeTask(title: "Stub Task", providerID: "stub")
    let ctx = makeHandler(stubProviderTasks: [existing])
    let urlString = "taskmato://start?provider=stub&id=\(existing.id.nativeID)"
    await ctx.handler.handle(URL(string: urlString)!)
    #expect(ctx.selectionStore.activeTask?.id == existing.id)
  }

  @Test func lookupByIDUnknownProviderIsIgnored() async {
    let ctx = makeHandler()
    await ctx.handler.handle(URL(string: "taskmato://start?provider=unknown&id=abc123")!)
    #expect(ctx.selectionStore.activeTask == nil)
  }

  @Test func lookupByIDIgnoresDisabledProvider() async {
    let existing = makeTask(title: "Disabled Task", providerID: "stub")
    let ctx = makeHandler(stubProviderTasks: [existing])
    // Disable the stub provider after setup.
    ctx.registry.disable(providerID: "stub")
    let urlString = "taskmato://start?provider=stub&id=\(existing.id.nativeID)"
    await ctx.handler.handle(URL(string: urlString)!)
    #expect(ctx.selectionStore.activeTask == nil)
  }

  // MARK: - Step 2: ID-only cross-provider fan-out

  @Test func idOnlyFanOutFindsTaskInStubProvider() async {
    let existing = makeTask(title: "Cross Provider", providerID: "stub")
    let ctx = makeHandler(stubProviderTasks: [existing])
    let urlString = "taskmato://start?id=\(existing.id.nativeID)"
    await ctx.handler.handle(URL(string: urlString)!)
    #expect(ctx.selectionStore.activeTask?.id == existing.id)
  }

  @Test func idOnlyFanOutUnknownIDIsIgnored() async {
    let ctx = makeHandler()
    await ctx.handler.handle(URL(string: "taskmato://start?id=nonexistent-id")!)
    #expect(ctx.selectionStore.activeTask == nil)
  }

  // MARK: - Step 3: Lookup by title in named provider

  @Test func lookupByTitleInNamedProvider() async {
    let existing = makeTask(title: "Write tests")
    let ctx = makeHandler(stubProviderTasks: [existing])
    await ctx.handler.handle(URL(string: "taskmato://start?provider=stub&title=Write%20tests")!)
    #expect(ctx.selectionStore.activeTask?.id == existing.id)
  }

  @Test func lookupByTitleIsCaseInsensitive() async {
    let existing = makeTask(title: "Write Tests")
    let ctx = makeHandler(stubProviderTasks: [existing])
    await ctx.handler.handle(URL(string: "taskmato://start?provider=stub&title=write%20tests")!)
    #expect(ctx.selectionStore.activeTask?.id == existing.id)
  }

  @Test func lookupByTitleIgnoresDisabledProvider() async {
    let existing = makeTask(title: "Disabled Title", providerID: "stub")
    let ctx = makeHandler(stubProviderTasks: [existing])
    ctx.registry.disable(providerID: "stub")
    await ctx.handler.handle(
      URL(string: "taskmato://start?provider=stub&title=Disabled%20Title")!)
    #expect(ctx.selectionStore.activeTask?.id.providerID == LocalProvider.providerID)
    #expect(ctx.selectionStore.activeTask?.title == "Disabled Title")
  }

  // MARK: - Step 4: Cross-provider title search

  @Test func crossProviderSearchFindsBeforeAdHoc() async {
    let existing = makeTask(title: "Design API")
    let ctx = makeHandler(stubProviderTasks: [existing])
    await ctx.handler.handle(URL(string: "taskmato://start?title=Design%20API")!)
    #expect(ctx.selectionStore.activeTask?.id.providerID == "stub")
  }

  @Test func disambiguationSetWhenMultipleMatches() async {
    let task1 = makeTask(title: "Write docs")
    let task2 = makeTask(title: "Write docs")
    let ctx = makeHandler(stubProviderTasks: [task1, task2])
    await ctx.handler.handle(URL(string: "taskmato://start?title=Write%20docs")!)
    #expect(ctx.selectionStore.activeTask == nil)
    #expect(ctx.handler.pendingDisambiguation?.count == 2)
  }

  @Test func disambiguationAdHocParamsSaved() async {
    let task1 = makeTask(title: "Review PR")
    let task2 = makeTask(title: "Review PR")
    let ctx = makeHandler(stubProviderTasks: [task1, task2])
    await ctx.handler.handle(URL(string: "taskmato://start?title=Review+PR&priority=high")!)
    #expect(ctx.handler.pendingAdHocParams?.title == "Review PR")
    #expect(ctx.handler.pendingAdHocParams?.priority == .high)
  }

  @Test func makeAdHocTaskFromDisambiguationUsesDefaultProvider() async throws {
    let task1 = makeTask(title: "Deploy")
    let task2 = makeTask(title: "Deploy")
    let ctx = makeHandler(stubProviderTasks: [task1, task2], enableLocalProvider: true)
    await ctx.handler.handle(URL(string: "taskmato://start?title=Deploy")!)
    let params = ctx.handler.pendingAdHocParams!
    let task = await ctx.handler.makeAdHocTask(from: params)
    #expect(task.id.providerID == LocalProvider.providerID)
    let localItems = try await ctx.localProvider.tasks(in: nil)
    #expect(localItems.map(\.title).contains("Deploy"))
  }

  // MARK: - URL scheme ignores sidebar selection

  @Test func urlSchemeTitleSearchIgnoresSidebarSelection() async {
    // Task lives in the stub provider (providerID: "stub"). The URL handler resolves
    // titles globally and has no access to the sidebar `SelectionStore`, so it is
    // structurally independent of the active sidebar selection.
    let existing = makeTask(title: "Global Task", providerID: "stub")
    let ctx = makeHandler(stubProviderTasks: [existing])
    await ctx.handler.handle(URL(string: "taskmato://start?title=Global%20Task")!)
    #expect(ctx.selectionStore.activeTask?.id == existing.id)
  }

  // MARK: - Invalid / noop cases

  @Test func wrongSchemeIsIgnored() async {
    let ctx = makeHandler()
    await ctx.handler.handle(URL(string: "https://example.com/start?title=Task")!)
    #expect(ctx.selectionStore.activeTask == nil)
  }

  @Test func wrongHostIsIgnored() async {
    let ctx = makeHandler()
    await ctx.handler.handle(URL(string: "taskmato://open?title=Task")!)
    #expect(ctx.selectionStore.activeTask == nil)
  }

  @Test func missingTitleAndIDIsIgnored() async {
    let ctx = makeHandler()
    await ctx.handler.handle(URL(string: "taskmato://start?priority=high")!)
    #expect(ctx.selectionStore.activeTask == nil)
  }

  @Test func emptyTitleIsIgnored() async {
    let ctx = makeHandler()
    await ctx.handler.handle(URL(string: "taskmato://start?title=")!)
    #expect(ctx.selectionStore.activeTask == nil)
  }
}
