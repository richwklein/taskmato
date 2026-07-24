//
//  MainWindowView.swift
//  Taskmato
//

import SwiftUI

/// The root view for the main application window.
///
/// A single ``NavigationSplitView`` places the universal ``AppSidebarView`` in the sidebar
/// and the current destination's surface in the detail column. Selection is owned by the
/// injected ``MainNavigation`` as an ``AppDestination``; the detail switches on it. Settings
/// open in a separate window via ⌘, or the app menu.
struct MainWindowView: View {

  var presenter: TimerPresenter
  var engine: SessionEngine
  var settings: AppSettings
  var statsViewModel: StatsViewModel
  var selectionStore: TaskSelectionStore
  var registry: ProviderRegistry
  var queryService: TaskQueryService
  var sidebarSelection: SelectionStore
  var nav: MainNavigation

  /// Bumped when the sidebar adds a task, forwarded into the task detail so it reloads.
  @State private var taskAddedToken = 0

  var body: some View {
    NavigationSplitView(
      columnVisibility: Binding(
        get: { nav.sidebarVisible ? .all : .detailOnly },
        set: { nav.sidebarVisible = $0 != .detailOnly }
      )
    ) {
      AppSidebarView(
        nav: nav,
        registry: registry,
        settings: settings,
        onTaskAdded: { taskAddedToken += 1 }
      )
      .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 300)
    } detail: {
      detail
    }
    .frame(minWidth: 640, minHeight: 400)
    .focusedSceneValue(\.destination, nav.destination)
    .focusedSceneValue(\.timerToggle, timerToggleAction)
    .focusedSceneValue(\.timerToggleTitle, timerToggleTitleValue)
    .focusedSceneValue(\.timerSkip, { presenter.skip() })
    .focusedSceneValue(\.timerStop, presenter.canStop ? { presenter.stop() } : nil)
  }

  /// The detail surface for the current destination.
  @ViewBuilder
  private var detail: some View {
    switch nav.destination {
    case .timer:
      TimerTabView(
        presenter: presenter,
        engine: engine,
        statsViewModel: statsViewModel,
        selectionStore: selectionStore,
        registry: registry,
        nav: nav
      )
    case .today, .list:
      TaskDetailView(
        selectionStore: selectionStore,
        registry: registry,
        queryService: queryService,
        sidebarSelection: sidebarSelection,
        nav: nav,
        settings: settings,
        refreshToken: taskAddedToken
      )
    case .stats:
      StatsTabView(statsViewModel: statsViewModel)
    }
  }

  // MARK: - Timer command helpers

  private var timerToggleAction: (() -> Void)? {
    if presenter.isRunning { return { presenter.pause() } }
    if presenter.isPaused { return { presenter.resume() } }
    guard selectionStore.activeTask != nil else { return nil }
    return { presenter.start() }
  }

  private var timerToggleTitleValue: String {
    if presenter.isRunning { return AppLabels.Timer.pause.title }
    if presenter.isPaused { return AppLabels.Timer.resume.title }
    return AppLabels.Timer.start.title
  }
}

#Preview {
  let engine = SessionEngine()
  let settings = AppSettings()
  let registry = ProviderRegistry()
  let selectionStore = SelectionStore(registry: registry)
  return MainWindowView(
    presenter: TimerPresenter(engine: engine, settings: settings),
    engine: engine,
    settings: settings,
    statsViewModel: .preview,
    selectionStore: TaskSelectionStore(),
    registry: registry,
    queryService: TaskQueryService(registry: registry, sorter: TaskSorter()),
    sidebarSelection: selectionStore,
    nav: MainNavigation(
      settings: settings, selectionStore: selectionStore, statsViewModel: .preview)
  )
}
