//
//  MainWindowView.swift
//  Taskmato
//

import SwiftUI

/// Tab ordering for the main window. Raw values are stable selection tags.
enum MainTab: Int {
  /// The Tasks tab — the landing tab; hosts the task browser and provider sidebar.
  case tasks = 0
  /// The Timer tab — focus/break controls; the popover handles most timer interaction.
  case timer = 1
  /// The Stats tab — Today / 7-day / All-time session summaries.
  case stats = 2
}

/// The root view for the main application window, hosting three-tab navigation.
///
/// Tabs in order: Tasks (landing), Timer, Stats. Settings opens in a separate window
/// via ⌘, or the app menu. Tab selection and sidebar visibility are owned by the
/// injected ``MainNavigation`` model.
struct MainWindowView: View {

  var presenter: TimerPresenter
  var engine: SessionEngine
  var settings: AppSettings
  var statsViewModel: StatsViewModel
  var selectionStore: TaskSelectionStore
  var registry: ProviderRegistry
  var queryService: TaskQueryService
  var sidebarSelection: SelectionStore
  @Bindable var nav: MainNavigation

  var body: some View {
    TabView(selection: $nav.selectedTab) {
      Tab(
        AppLabels.Tab.tasks.title, systemImage: AppLabels.Tab.tasks.systemImage,
        value: MainTab.tasks
      ) {
        TasksTabView(
          selectionStore: selectionStore,
          registry: registry,
          queryService: queryService,
          sidebarSelection: sidebarSelection,
          nav: nav,
          settings: settings
        )
      }

      Tab(
        AppLabels.Tab.timer.title, systemImage: AppLabels.Tab.timer.systemImage,
        value: MainTab.timer
      ) {
        TimerTabView(
          presenter: presenter,
          engine: engine,
          statsViewModel: statsViewModel,
          selectionStore: selectionStore,
          registry: registry,
          nav: nav
        )
      }

      Tab(
        AppLabels.Tab.stats.title, systemImage: AppLabels.Tab.stats.systemImage,
        value: MainTab.stats
      ) {
        StatsTabView(statsViewModel: statsViewModel)
      }
    }
    .frame(minWidth: 640, minHeight: 400)
    .focusedSceneValue(\.selectedTab, nav.selectedTab)
    .focusedSceneValue(\.timerToggle, timerToggleAction)
    .focusedSceneValue(\.timerToggleTitle, timerToggleTitleValue)
    .focusedSceneValue(\.timerSkip, { presenter.skip() })
    .focusedSceneValue(\.timerStop, presenter.canStop ? { presenter.stop() } : nil)
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
  return MainWindowView(
    presenter: TimerPresenter(engine: engine, settings: settings),
    engine: engine,
    settings: settings,
    statsViewModel: .preview,
    selectionStore: TaskSelectionStore(),
    registry: registry,
    queryService: TaskQueryService(registry: registry, sorter: TaskSorter()),
    sidebarSelection: SelectionStore(registry: registry),
    nav: MainNavigation(settings: settings)
  )
}
