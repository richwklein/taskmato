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

  private func makeHandler(stubProviderTasks: [TaskItem] = []) -> HandlerContext {
    let defaults = UserDefaults(suiteName: UUID().uuidString)!
    let selectionStore = TaskSelectionStore(defaults: defaults)
    let engine = SessionEngine()
    let registry = TaskRegistry(defaults: defaults)

    if !stubProviderTasks.isEmpty {
      let stub = StubTaskProvider(id: "stub", tasks: stubProviderTasks)
      registry.register(stub)
      registry.enable(stub)
    }

    let handler = URLSchemeHandler(
      registry: registry,
      selectionStore: selectionStore,
      engine: engine
    )
    return HandlerContext(handler: handler, selectionStore: selectionStore)
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

  // MARK: - Ad-hoc task creation (transient)

  @Test func adHocTaskSelectedWithAdhocProviderID() async {
    let ctx = makeHandler()
    await ctx.handler.handle(URL(string: "taskmato://start?title=Buy%20groceries")!)
    #expect(ctx.selectionStore.activeTask?.title == "Buy groceries")
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

  @Test func adHocTaskWithList() async {
    let ctx = makeHandler()
    await ctx.handler.handle(URL(string: "taskmato://start?title=Listed&list=Work")!)
    #expect(ctx.selectionStore.activeTask?.list?.name == "Work")
  }

  @Test func adHocTaskIsTransientNotInRegistry() async {
    let ctx = makeHandler()
    await ctx.handler.handle(URL(string: "taskmato://start?title=Transient+Task")!)
    // Task is active but lives only in the selection store, not a provider
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

  @Test func crossProviderNoMatchCreatesTransientAdHoc() async {
    let ctx = makeHandler()
    await ctx.handler.handle(URL(string: "taskmato://start?title=Brand+New+Task")!)
    #expect(ctx.selectionStore.activeTask?.title == "Brand New Task")
    #expect(ctx.selectionStore.activeTask?.id.providerID == "adhoc")
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

  @Test func makeAdHocTaskFromDisambiguationIsTransient() async {
    let task1 = makeTask(title: "Deploy")
    let task2 = makeTask(title: "Deploy")
    let ctx = makeHandler(stubProviderTasks: [task1, task2])
    await ctx.handler.handle(URL(string: "taskmato://start?title=Deploy")!)
    let params = ctx.handler.pendingAdHocParams!
    let task = ctx.handler.makeAdHocTask(from: params)
    #expect(task.id.providerID == "adhoc")
    #expect(task.title == "Deploy")
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
