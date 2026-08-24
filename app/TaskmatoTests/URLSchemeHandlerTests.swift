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
  let registry: ProviderRegistry
  let activeTaskStore: ActiveTaskStore
  let localProvider: LocalProvider
  let settings: AppSettings
  let errorPresenter: ErrorPresenter
  let engine: SessionEngine
}

// MARK: - Fakes

private final class StubTaskProvider: TaskProvider {
  let id: ProviderID
  let displayName: String
  let icon: String = "square"
  let entitlement: ProviderEntitlement = .free
  private let stubbedTasks: [TaskItem]

  init(id: ProviderID, tasks: [TaskItem] = []) {
    self.id = id
    self.displayName = id.rawValue
    self.stubbedTasks = tasks
  }

  nonisolated func authorize() async throws {}
  func lists() async throws -> [TaskList] { [] }
  func tasks(in list: TaskList?) async throws -> [TaskItem] { stubbedTasks }
  func observe() -> AsyncStream<[TaskItem]>? { nil }
}

private final class StubWritableProvider: WritableTaskProvider {
  let id: ProviderID
  let displayName: String
  let icon: String = "square"
  let entitlement: ProviderEntitlement = .free
  let defaultListID: String? = "default"
  let contentFormat: ContentFormat = .markdown

  init(id: ProviderID) {
    self.id = id
    self.displayName = id.rawValue
  }

  nonisolated func authorize() async throws {}
  func lists() async throws -> [TaskList] {
    [TaskList(id: "default", providerID: id, name: "Default")]
  }
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
      dueDateIncludesTime: draft.dueDateIncludesTime,
      scheduledDate: nil,
      startDate: nil,
      list: nil,
      section: draft.section,
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

/// `true` while `state` is `.running`, regardless of phase, start time, or duration.
private func isRunning(_ state: SessionState) -> Bool {
  if case .running = state { return true }
  return false
}

private func makeTempURL() -> URL {
  FileManager.default.temporaryDirectory
    .appendingPathComponent(UUID().uuidString)
    .appendingPathExtension("json")
}

private func makeTask(title: String, providerID: ProviderID = "stub") -> TaskItem {
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

// MARK: - Tests

@MainActor
struct URLSchemeHandlerTests {

  // MARK: - Helpers

  /// Builds a fully wired handler. Pass `enableLocalProvider: false` to test the transient path.
  private func makeHandler(
    stubProviderTasks: [TaskItem] = [],
    enableLocalProvider: Bool = true,
    defaultWritableProviderID: ProviderID? = nil
  ) -> HandlerContext {
    let defaults = UserDefaults(suiteName: UUID().uuidString)!
    let settingsStore = SettingsStore(defaults: defaults)
    let activeTaskStore = ActiveTaskStore(store: settingsStore)
    let engine = SessionEngine()
    let registry = ProviderRegistry(store: settingsStore)
    let localProvider = LocalProvider(fileURL: makeTempURL())
    let settings = AppSettings(store: settingsStore)
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

    let errorPresenter = ErrorPresenter()
    let destinationResolver = TaskDestinationResolver(registry: registry, settings: settings)
    let handler = URLSchemeHandler(
      registry: registry,
      queryService: TaskQueryService(registry: registry, sorter: TaskSorter()),
      activeTaskStore: activeTaskStore,
      engine: engine,
      settings: settings,
      nav: MainNavigation(
        settings: settings,
        selectionStore: SelectionStore(registry: registry, store: settingsStore),
        statsViewModel: .preview),
      errorPresenter: errorPresenter,
      destinationResolver: destinationResolver
    )
    return HandlerContext(
      handler: handler,
      registry: registry,
      activeTaskStore: activeTaskStore,
      localProvider: localProvider,
      settings: settings,
      errorPresenter: errorPresenter,
      engine: engine
    )
  }

  // MARK: - Ad-hoc task creation (LocalProvider enabled — default provider)

  @Test func adHocTaskWrittenToLocalProviderWhenEnabled() async throws {
    let ctx = makeHandler(enableLocalProvider: true)
    await ctx.handler.handle(URL(string: "taskmato://start?title=Buy%20groceries")!)
    #expect(ctx.activeTaskStore.activeTask?.title == "Buy groceries")
    #expect(ctx.activeTaskStore.activeTask?.id.providerID == LocalProvider.providerID)
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

  // MARK: - Ad-hoc task creation (no writable provider — error, no fallback)

  @Test func adHocTaskSurfacesErrorWhenNoWritableProvider() async {
    let ctx = makeHandler(enableLocalProvider: false)
    await ctx.handler.handle(URL(string: "taskmato://start?title=Transient+Task")!)
    // No enabled writable provider → no session starts and the failure is surfaced.
    #expect(ctx.activeTaskStore.activeTask == nil)
    #expect(ctx.errorPresenter.current != nil)
  }

  @Test func adHocTaskWithHighPriority() async {
    let ctx = makeHandler()
    await ctx.handler.handle(URL(string: "taskmato://start?title=Urgent&priority=high")!)
    #expect(ctx.activeTaskStore.activeTask?.priority == .high)
  }

  @Test func adHocTaskWithDueDate() async throws {
    let ctx = makeHandler()
    await ctx.handler.handle(URL(string: "taskmato://start?title=Due+Task&due=2026-12-01")!)
    let dueDate = try #require(ctx.activeTaskStore.activeTask?.dueDate)
    let comps = Calendar.current.dateComponents([.year, .month, .day], from: dueDate)
    // Regression: --due must parse as local midnight, not UTC midnight — ISO8601DateFormatter's
    // UTC parsing landed on the previous local day west of UTC.
    #expect(comps.year == 2026)
    #expect(comps.month == 12)
    #expect(comps.day == 1)
    #expect(ctx.activeTaskStore.activeTask?.dueDateIncludesTime == false)
  }

  @Test func adHocTaskWithDueTimeSetsDueDateIncludesTime() async throws {
    let ctx = makeHandler()
    await ctx.handler.handle(
      URL(string: "taskmato://start?title=Due+Task+With+Time&due=2026-12-01+14:30")!)
    let dueDate = try #require(ctx.activeTaskStore.activeTask?.dueDate)
    let comps = Calendar.current.dateComponents(
      [.year, .month, .day, .hour, .minute], from: dueDate)
    #expect(comps.year == 2026)
    #expect(comps.month == 12)
    #expect(comps.day == 1)
    #expect(comps.hour == 14)
    #expect(comps.minute == 30)
    #expect(ctx.activeTaskStore.activeTask?.dueDateIncludesTime == true)
  }

  @Test func adHocTaskWithMalformedDueTimeYieldsNoDueDate() async {
    let ctx = makeHandler()
    await ctx.handler.handle(
      URL(string: "taskmato://start?title=Bad+Due+Time&due=2026-12-01+not-a-time")!)
    #expect(ctx.activeTaskStore.activeTask?.dueDate == nil)
  }

  @Test func adHocTaskWithSectionPassesSectionThroughToDraft() async throws {
    let ctx = makeHandler(enableLocalProvider: true)
    // LocalProvider has no sections concept, so verify via a stub provider that echoes
    // draft.section back onto the created TaskItem.
    let stub = StubWritableProvider(id: "sectioned")
    ctx.registry.register(stub)
    ctx.registry.enable(stub)
    await ctx.handler.handle(
      URL(string: "taskmato://start?title=Sectioned&provider=sectioned&section=Backlog")!)
    #expect(ctx.activeTaskStore.activeTask?.section == "Backlog")
  }

  @Test func adHocTaskWithoutSectionLeavesDraftSectionNil() async throws {
    let ctx = makeHandler(enableLocalProvider: true)
    let stub = StubWritableProvider(id: "sectioned")
    ctx.registry.register(stub)
    ctx.registry.enable(stub)
    await ctx.handler.handle(
      URL(string: "taskmato://start?title=Unsectioned&provider=sectioned")!)
    #expect(ctx.activeTaskStore.activeTask?.section == nil)
  }

  // MARK: - Ad-hoc: URL param provider override

  @Test func adHocTaskURLProviderParamTargetsSpecificProvider() async throws {
    let ctx = makeHandler(enableLocalProvider: true)
    await ctx.handler.handle(
      URL(string: "taskmato://start?title=Override&provider=\(LocalProvider.providerID)")!)
    #expect(ctx.activeTaskStore.activeTask?.id.providerID == LocalProvider.providerID)
    let items = try await ctx.localProvider.tasks(in: nil)
    #expect(items.map(\.title).contains("Override"))
  }

  @Test func adHocTaskURLProviderParamSurfacesErrorWhenNoEnabledWritable() async {
    // provider= refers to a disabled provider and none other is enabled → error, no session.
    let ctx = makeHandler(enableLocalProvider: true)
    ctx.registry.disable(providerID: LocalProvider.providerID)
    await ctx.handler.handle(
      URL(string: "taskmato://start?title=Fallback&provider=\(LocalProvider.providerID)")!)
    #expect(ctx.activeTaskStore.activeTask == nil)
    #expect(ctx.errorPresenter.current != nil)
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

    #expect(ctx.activeTaskStore.activeTask?.id.providerID == "zzz-default")
  }

  // MARK: - Ad-hoc: settings default writable provider

  @Test func adHocTaskUsesSettingsDefaultProvider() async throws {
    let ctx = makeHandler(
      enableLocalProvider: true,
      defaultWritableProviderID: LocalProvider.providerID
    )
    await ctx.handler.handle(URL(string: "taskmato://start?title=Settings+Task")!)
    #expect(ctx.activeTaskStore.activeTask?.id.providerID == LocalProvider.providerID)
    let items = try await ctx.localProvider.tasks(in: nil)
    #expect(items.map(\.title).contains("Settings Task"))
  }

  @Test func adHocTaskIgnoresSettingsDefaultWhenProviderDisabled() async {
    let ctx = makeHandler(
      enableLocalProvider: false,
      defaultWritableProviderID: LocalProvider.providerID
    )
    await ctx.handler.handle(URL(string: "taskmato://start?title=No+Provider")!)
    // Settings points at a disabled provider and none is enabled → error, no session.
    #expect(ctx.activeTaskStore.activeTask == nil)
    #expect(ctx.errorPresenter.current != nil)
  }

  // MARK: - Step 1: Lookup by provider + ID

  @Test func lookupByIDInStubProvider() async {
    let existing = makeTask(title: "Stub Task", providerID: "stub")
    let ctx = makeHandler(stubProviderTasks: [existing])
    let urlString = "taskmato://start?provider=stub&id=\(existing.id.nativeID)"
    await ctx.handler.handle(URL(string: urlString)!)
    #expect(ctx.activeTaskStore.activeTask?.id == existing.id)
  }

  @Test func lookupByIDUnknownProviderIsIgnored() async {
    let ctx = makeHandler()
    await ctx.handler.handle(URL(string: "taskmato://start?provider=unknown&id=abc123")!)
    #expect(ctx.activeTaskStore.activeTask == nil)
  }

  @Test func lookupByIDIgnoresDisabledProvider() async {
    let existing = makeTask(title: "Disabled Task", providerID: "stub")
    let ctx = makeHandler(stubProviderTasks: [existing])
    // Disable the stub provider after setup.
    ctx.registry.disable(providerID: "stub")
    let urlString = "taskmato://start?provider=stub&id=\(existing.id.nativeID)"
    await ctx.handler.handle(URL(string: urlString)!)
    #expect(ctx.activeTaskStore.activeTask == nil)
  }

  // MARK: - Step 2: ID-only cross-provider fan-out

  @Test func idOnlyFanOutFindsTaskInStubProvider() async {
    let existing = makeTask(title: "Cross Provider", providerID: "stub")
    let ctx = makeHandler(stubProviderTasks: [existing])
    let urlString = "taskmato://start?id=\(existing.id.nativeID)"
    await ctx.handler.handle(URL(string: urlString)!)
    #expect(ctx.activeTaskStore.activeTask?.id == existing.id)
  }

  @Test func idOnlyFanOutUnknownIDIsIgnored() async {
    let ctx = makeHandler()
    await ctx.handler.handle(URL(string: "taskmato://start?id=nonexistent-id")!)
    #expect(ctx.activeTaskStore.activeTask == nil)
  }

  // MARK: - Step 3: Lookup by title in named provider

  @Test func lookupByTitleInNamedProvider() async {
    let existing = makeTask(title: "Write tests")
    let ctx = makeHandler(stubProviderTasks: [existing])
    await ctx.handler.handle(URL(string: "taskmato://start?provider=stub&title=Write%20tests")!)
    #expect(ctx.activeTaskStore.activeTask?.id == existing.id)
  }

  @Test func lookupByTitleIsCaseInsensitive() async {
    let existing = makeTask(title: "Write Tests")
    let ctx = makeHandler(stubProviderTasks: [existing])
    await ctx.handler.handle(URL(string: "taskmato://start?provider=stub&title=write%20tests")!)
    #expect(ctx.activeTaskStore.activeTask?.id == existing.id)
  }

  @Test func lookupByTitleIgnoresDisabledProvider() async {
    let existing = makeTask(title: "Disabled Title", providerID: "stub")
    let ctx = makeHandler(stubProviderTasks: [existing])
    ctx.registry.disable(providerID: "stub")
    await ctx.handler.handle(
      URL(string: "taskmato://start?provider=stub&title=Disabled%20Title")!)
    #expect(ctx.activeTaskStore.activeTask?.id.providerID == LocalProvider.providerID)
    #expect(ctx.activeTaskStore.activeTask?.title == "Disabled Title")
  }

  // MARK: - Step 4: Cross-provider title search

  @Test func crossProviderSearchFindsBeforeAdHoc() async {
    let existing = makeTask(title: "Design API")
    let ctx = makeHandler(stubProviderTasks: [existing])
    await ctx.handler.handle(URL(string: "taskmato://start?title=Design%20API")!)
    #expect(ctx.activeTaskStore.activeTask?.id.providerID == "stub")
  }

  @Test func disambiguationSetWhenMultipleMatches() async {
    let task1 = makeTask(title: "Write docs")
    let task2 = makeTask(title: "Write docs")
    let ctx = makeHandler(stubProviderTasks: [task1, task2])
    await ctx.handler.handle(URL(string: "taskmato://start?title=Write%20docs")!)
    #expect(ctx.activeTaskStore.activeTask == nil)
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
    let task = try #require(await ctx.handler.makeAdHocTask(from: params))
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
    #expect(ctx.activeTaskStore.activeTask?.id == existing.id)
  }

  // MARK: - Invalid / noop cases

  @Test func wrongSchemeIsIgnored() async {
    let ctx = makeHandler()
    await ctx.handler.handle(URL(string: "https://example.com/start?title=Task")!)
    #expect(ctx.activeTaskStore.activeTask == nil)
  }

  @Test func wrongHostIsIgnored() async {
    let ctx = makeHandler()
    await ctx.handler.handle(URL(string: "taskmato://open?title=Task")!)
    #expect(ctx.activeTaskStore.activeTask == nil)
  }

  @Test func missingTitleAndIDIsIgnored() async {
    let ctx = makeHandler()
    await ctx.handler.handle(URL(string: "taskmato://start?priority=high")!)
    #expect(ctx.activeTaskStore.activeTask == nil)
  }

  @Test func emptyTitleIsIgnored() async {
    let ctx = makeHandler()
    await ctx.handler.handle(URL(string: "taskmato://start?title=")!)
    #expect(ctx.activeTaskStore.activeTask == nil)
  }

  // MARK: - Issue #595: start-vs-stage delegation to activate(_:)

  @Test func runningSessionStagesResolvedTaskWithoutClobberingActiveTask() async {
    let initialTask = makeTask(title: "Already Running", providerID: "stub")
    let ctx = makeHandler(stubProviderTasks: [initialTask])
    ctx.activeTaskStore.track(initialTask)
    ctx.engine.applyDurations(from: ctx.settings)
    ctx.engine.start(phase: .focus)

    await ctx.handler.handle(URL(string: "taskmato://start?title=New+Ad+Hoc")!)

    #expect(ctx.activeTaskStore.activeTask?.id == initialTask.id)
    #expect(ctx.activeTaskStore.stagedTask?.title == "New Ad Hoc")
    #expect(isRunning(ctx.engine.state))
  }

  @Test func idleWithFocusNextStartsSession() async {
    let ctx = makeHandler()
    await ctx.handler.handle(URL(string: "taskmato://start?title=Idle+Start")!)
    #expect(ctx.activeTaskStore.activeTask?.title == "Idle Start")
    #expect(ctx.activeTaskStore.stagedTask == nil)
    #expect(isRunning(ctx.engine.state))
  }

  @Test func alwaysStartsWhenIdleEvenWithAutoStartDisabled() async {
    let ctx = makeHandler()
    ctx.settings.autoStartNextPhase = false
    await ctx.handler.handle(URL(string: "taskmato://start?title=No+AutoStart+Gate")!)
    #expect(isRunning(ctx.engine.state))
  }

  @Test func idleWithBreakQueuedStagesResolvedTaskWithoutStartingFocus() async {
    let ctx = makeHandler()
    ctx.engine.enqueuePhase(.shortBreak)
    #expect(ctx.engine.state == .idle)
    #expect(ctx.engine.queuedPhase == .shortBreak)

    await ctx.handler.handle(URL(string: "taskmato://start?title=Queued+Break")!)

    #expect(ctx.activeTaskStore.stagedTask?.title == "Queued Break")
    #expect(ctx.activeTaskStore.activeTask == nil)
    #expect(ctx.engine.state == .idle)
    #expect(ctx.engine.queuedPhase == .shortBreak)
  }

  @Test func disambiguationActivateDuringRunningSessionDoesNotClobber() async {
    let initialTask = makeTask(title: "Initial", providerID: "stub")
    let otherTask = makeTask(title: "Other", providerID: "stub")
    let ctx = makeHandler(stubProviderTasks: [initialTask, otherTask])
    ctx.activeTaskStore.track(initialTask)
    ctx.engine.applyDurations(from: ctx.settings)
    ctx.engine.start(phase: .focus)

    ctx.handler.activate(otherTask)

    #expect(ctx.activeTaskStore.activeTask?.id == initialTask.id)
    #expect(ctx.activeTaskStore.stagedTask?.id == otherTask.id)
  }
}
