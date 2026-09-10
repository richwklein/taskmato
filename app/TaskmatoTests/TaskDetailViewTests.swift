//
//  TaskDetailViewTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

private func makeItem(providerID: ProviderID, nativeID: String, title: String) -> TaskItem {
  TaskItem(
    id: TaskRef(providerID: providerID, nativeID: nativeID),
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

// MARK: - Test context

/// Every collaborator a real `TaskDetailView` needs, wired over one isolated `UserDefaults`
/// suite (mirrors `ActiveTaskViewTests`'s `ViewContext`). `startFocus(_:minutes:)` is
/// non-`private`, touches no `@State`, and depends only on these, so it is exercised directly
/// without hosting the view.
@MainActor
private struct ViewContext {
  let engine: SessionEngine
  let settings: AppSettings
  let activeTaskStore: ActiveTaskStore
  let registry: ProviderRegistry
  let queryService: TaskQueryService
  let destinationResolver: TaskDestinationResolver
  let sidebarSelection: SelectionStore
  let nav: MainNavigation
  let errorPresenter: ErrorPresenter
  let presenter: TimerPresenter

  func view() -> TaskDetailView {
    TaskDetailView(
      activeTaskStore: activeTaskStore, registry: registry, queryService: queryService,
      destinationResolver: destinationResolver, sidebarSelection: sidebarSelection, nav: nav,
      settings: settings, errorPresenter: errorPresenter, presenter: presenter)
  }
}

@MainActor
private func makeContext() -> ViewContext {
  let settingsStore = SettingsStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
  let engine = SessionEngine()
  let settings = AppSettings(store: settingsStore)
  let activeTaskStore = ActiveTaskStore(store: settingsStore)
  let registry = ProviderRegistry(store: settingsStore)
  let queryService = TaskQueryService(registry: registry, sorter: TaskSorter())
  let destinationResolver = TaskDestinationResolver(registry: registry, settings: settings)
  let sidebarSelection = SelectionStore(registry: registry, store: settingsStore)
  let nav = MainNavigation(
    settings: settings, selectionStore: sidebarSelection, statsViewModel: .preview,
    store: settingsStore)
  let presenter = TimerPresenter(
    engine: engine, settings: settings, activeTaskStore: activeTaskStore)
  // Mirrors `AppComposition.wireFocusHandoff`'s `onTaskPicked` wiring, so this context can
  // reproduce the §8 ordering bug: a pick that starts focus before `focusMinutes` is written
  // would start it at the stale length.
  let coordinator = FocusHandoffCoordinator(presenter: presenter, settings: settings)
  activeTaskStore.onTaskPicked = { coordinator.startFocusOnPick() }
  return ViewContext(
    engine: engine, settings: settings, activeTaskStore: activeTaskStore, registry: registry,
    queryService: queryService, destinationResolver: destinationResolver,
    sidebarSelection: sidebarSelection, nav: nav, errorPresenter: ErrorPresenter(),
    presenter: presenter)
}

// MARK: - Tests

/// Covers the §8 ordering fix: `settings.focusMinutes` must be written before `track(_:)` so a
/// pick that starts focus (via `onTaskPicked`, gated on `startFocusOnTaskPick`) already sees the
/// chosen preset rather than the stale length.
@MainActor
struct TaskDetailViewTests {

  @Test func startFocusFromIdleRunsAPhaseAtTheChosenLength() {
    let ctx = makeContext()
    ctx.settings.startFocusOnTaskPick = true
    let task = makeItem(providerID: "alpha", nativeID: "1", title: "Write plan")

    ctx.view().startFocus(task, minutes: 45)

    guard case .running(let phase, _, let duration) = ctx.engine.state else {
      Issue.record("Expected a running focus phase, got \(ctx.engine.state)")
      return
    }
    #expect(phase == .focus)
    #expect(duration == 45 * 60)
    #expect(ctx.activeTaskStore.activeTask == task)
  }
}
