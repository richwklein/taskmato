//
//  MainWindowView.swift
//  Taskmato
//

import AppKit
import SwiftUI

/// The root view for the main application window.
///
/// A single ``NavigationSplitView`` places the universal ``AppSidebarView`` in the sidebar
/// and the current destination's surface in the detail column. Selection is owned by the
/// injected ``MainNavigation`` as an ``AppDestination``; the detail switches on it. Settings
/// open in a separate window via ⌘, or the app menu.
struct MainWindowView: View {

  var presenter: TimerPresenter
  var nextUpPresenter: NextUpPresenter
  var engine: SessionEngine
  var settings: AppSettings
  var statsViewModel: StatsViewModel
  var activeTaskStore: ActiveTaskStore
  var registry: ProviderRegistry
  var queryService: TaskQueryService
  var destinationResolver: TaskDestinationResolver
  var sidebarSelection: SelectionStore
  var nav: MainNavigation
  var errorPresenter: ErrorPresenter

  @Environment(\.openWindow) private var openWindow

  /// Bumped when the sidebar adds a task, forwarded into the task detail so it reloads.
  @State private var taskAddedToken = 0

  /// Which session indicators (strip / sidebar badge) the window shows right now.
  private var indicators: SessionIndicators {
    SessionIndicators(isNonIdle: presenter.canStop, onTimer: nav.destination == .timer)
  }

  var body: some View {
    NavigationSplitView(
      columnVisibility: Binding(
        get: { nav.sidebarVisible ? .all : .detailOnly },
        set: { nav.sidebarVisible = $0 != .detailOnly }
      )
    ) {
      AppSidebarView(
        nav: nav,
        presenter: presenter,
        registry: registry,
        destinationResolver: destinationResolver,
        settings: settings,
        errorPresenter: errorPresenter,
        onTaskAdded: { taskAddedToken += 1 }
      )
      .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 300)
    } detail: {
      VStack(spacing: 0) {
        ErrorBannerView(presenter: errorPresenter)
        detail
        if indicators.showStrip {
          Divider()
          TimerStripView(
            presenter: presenter, engine: engine, activeTaskStore: activeTaskStore,
            registry: registry, nav: nav, errorPresenter: errorPresenter
          ) {
            nav.destination = .timer
          }
        }
      }
      .animation(.default, value: errorPresenter.current)
    }
    .frame(minWidth: 640, minHeight: 400)
    .focusedSceneValue(\.timerToggle, timerToggleAction)
    .focusedSceneValue(\.timerToggleTitle, timerToggleTitleValue)
    .focusedSceneValue(\.timerSkip, { presenter.skip() })
    .focusedSceneValue(\.timerStop, presenter.canStop ? { presenter.stop() } : nil)
    .onAppear {
      // The main window is the primary surface, so it owns the `openWindow` plumbing: it
      // binds the reopen action used by external activations (notification tap,
      // `taskmato://`) to restore a closed window (design doc 0008, D1/D5).
      nav.bindOpenMainWindow {
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: "main")
      }
    }
  }

  /// The detail surface for the current destination.
  @ViewBuilder
  private var detail: some View {
    switch nav.destination {
    case .timer:
      TimerTabView(
        presenter: presenter,
        nextUpPresenter: nextUpPresenter,
        engine: engine,
        statsViewModel: statsViewModel,
        activeTaskStore: activeTaskStore,
        registry: registry,
        nav: nav,
        errorPresenter: errorPresenter
      )
    case .today, .list:
      TaskDetailView(
        activeTaskStore: activeTaskStore,
        registry: registry,
        queryService: queryService,
        destinationResolver: destinationResolver,
        sidebarSelection: sidebarSelection,
        nav: nav,
        settings: settings,
        errorPresenter: errorPresenter,
        presenter: presenter,
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
    guard activeTaskStore.activeTask != nil else { return nil }
    return { presenter.start() }
  }

  private var timerToggleTitleValue: String {
    if presenter.isRunning { return AppLabels.Timer.pause.title }
    if presenter.isPaused { return AppLabels.Timer.resume.title }
    return AppLabels.Timer.start.title
  }
}

#if DEBUG
  #Preview {
    let engine = SessionEngine()
    let settings = AppSettings()
    let registry = ProviderRegistry()
    let sidebarSelectionStore = SelectionStore(registry: registry)
    let timerPresenter = TimerPresenter(engine: engine, settings: settings)
    MainWindowView(
      presenter: timerPresenter,
      nextUpPresenter: NextUpPresenter(
        presenter: timerPresenter, activeTaskStore: ActiveTaskStore(), settings: settings),
      engine: engine,
      settings: settings,
      statsViewModel: .preview,
      activeTaskStore: ActiveTaskStore(),
      registry: registry,
      queryService: TaskQueryService(registry: registry, sorter: TaskSorter()),
      destinationResolver: TaskDestinationResolver(registry: registry, settings: settings),
      sidebarSelection: sidebarSelectionStore,
      nav: MainNavigation(
        settings: settings, selectionStore: sidebarSelectionStore, statsViewModel: .preview),
      errorPresenter: ErrorPresenter()
    )
  }
#endif
