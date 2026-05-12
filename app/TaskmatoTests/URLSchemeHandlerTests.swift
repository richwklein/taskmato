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
  let selectionStore: TaskSelectionStore
  let localProvider: LocalProvider
}

// MARK: - Fakes

private final class StubTaskProvider: TaskProvider {
  let id: String
  let displayName: String
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
    enableLocalProvider: Bool = true
  ) -> HandlerContext {
    let defaults = UserDefaults(suiteName: UUID().uuidString)!
    let selectionStore = TaskSelectionStore(defaults: defaults)
    let engine = SessionEngine()
    let registry = TaskRegistry(defaults: defaults)
    let localProvider = LocalProvider(fileURL: makeTempURL())

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
      settings: AppSettings(),
      localProvider: localProvider
    )
    return HandlerContext(
      handler: handler, selectionStore: selectionStore, localProvider: localProvider)
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

  // MARK: - Ad-hoc task creation (LocalProvider enabled)

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
    ctx.localProvider.createList(name: "Work")
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

  @Test func makeAdHocTaskFromDisambiguationUsesLocalProvider() async throws {
    let task1 = makeTask(title: "Deploy")
    let task2 = makeTask(title: "Deploy")
    let ctx = makeHandler(stubProviderTasks: [task1, task2], enableLocalProvider: true)
    await ctx.handler.handle(URL(string: "taskmato://start?title=Deploy")!)
    let params = ctx.handler.pendingAdHocParams!
    let task = ctx.handler.makeAdHocTask(from: params)
    #expect(task.id.providerID == LocalProvider.providerID)
    let localItems = try await ctx.localProvider.tasks(in: nil)
    #expect(localItems.map(\.title).contains("Deploy"))
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
