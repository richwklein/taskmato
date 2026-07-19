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

  var engine: SessionEngine
  var settings: AppSettings
  var store: SessionStore
  var selectionStore: TaskSelectionStore
  var registry: TaskRegistry
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
          nav: nav,
          settings: settings
        )
      }

      Tab(
        AppLabels.Tab.timer.title, systemImage: AppLabels.Tab.timer.systemImage,
        value: MainTab.timer
      ) {
        TimerTabView(
          engine: engine,
          settings: settings,
          store: store,
          selectionStore: selectionStore,
          registry: registry,
          nav: nav,
          nextStartPhase: engine.queuedPhase ?? .focus,
          nextBreakPhase: engine.nextBreakPhase(longBreakAfter: settings.longBreakAfterSessions)
        )
      }

      Tab(
        AppLabels.Tab.stats.title, systemImage: AppLabels.Tab.stats.systemImage,
        value: MainTab.stats
      ) {
        StatsTabView(store: store)
      }
    }
    .frame(minWidth: 640, minHeight: 400)
    .focusedSceneValue(\.selectedTab, nav.selectedTab)
    .focusedSceneValue(\.timerToggle, timerToggleAction)
    .focusedSceneValue(\.timerToggleTitle, timerToggleTitleValue)
    .focusedSceneValue(\.timerSkip, { skipPhase() })
    .focusedSceneValue(\.timerStop, engine.state != .idle ? { engine.stop() } : nil)
  }

  // MARK: - Timer command helpers

  private var timerToggleAction: (() -> Void)? {
    if engine.isRunning { return { engine.pause() } }
    if case .paused = engine.state { return { engine.resume() } }
    guard selectionStore.activeTask != nil else { return nil }
    return { startSession() }
  }

  private var timerToggleTitleValue: String {
    if engine.isRunning { return AppLabels.Timer.pause.title }
    if case .paused = engine.state { return AppLabels.Timer.resume.title }
    return AppLabels.Timer.start.title
  }

  private func startSession() {
    engine.focusDuration = settings.focusDuration
    engine.shortBreakDuration = settings.shortBreakDuration
    engine.longBreakDuration = settings.longBreakDuration
    engine.start(phase: engine.queuedPhase ?? .focus)
  }

  private func skipPhase() {
    engine.focusDuration = settings.focusDuration
    engine.shortBreakDuration = settings.shortBreakDuration
    engine.longBreakDuration = settings.longBreakDuration
    engine.skip(nextBreak: engine.nextBreakPhase(longBreakAfter: settings.longBreakAfterSessions))
  }
}

#Preview {
  MainWindowView(
    engine: SessionEngine(),
    settings: AppSettings(),
    store: SessionStore(),
    selectionStore: TaskSelectionStore(),
    registry: TaskRegistry(),
    nav: MainNavigation(settings: AppSettings())
  )
}
