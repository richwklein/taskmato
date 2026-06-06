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
      Tab("Tasks", systemImage: "checklist", value: MainTab.tasks) {
        TasksTabView(
          selectionStore: selectionStore,
          registry: registry,
          nav: nav,
          settings: settings
        )
      }

      Tab("Timer", systemImage: "timer", value: MainTab.timer) {
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

      Tab("Stats", systemImage: "chart.bar", value: MainTab.stats) {
        StatsTabView(store: store)
      }
    }
    .frame(minWidth: 640, minHeight: 400)
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
