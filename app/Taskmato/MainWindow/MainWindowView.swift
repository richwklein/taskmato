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
/// via ⌘, or the app menu.
struct MainWindowView: View {

  var engine: SessionEngine
  var settings: AppSettings
  var store: SessionStore
  var selectionStore: TaskSelectionStore
  var registry: TaskRegistry

  @State private var selectedTab: MainTab = .tasks

  var body: some View {
    TabView(selection: $selectedTab) {
      Tab("Tasks", systemImage: "checklist", value: MainTab.tasks) {
        TasksTabView(
          selectionStore: selectionStore,
          registry: registry,
          selectedTab: $selectedTab,
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
          nextStartPhase: engine.queuedPhase ?? .focus,
          nextBreakPhase: engine.nextBreakPhase(longBreakAfter: settings.longBreakAfterSessions)
        )
      }

      Tab("Stats", systemImage: "chart.bar", value: MainTab.stats) {
        StatsTabView(store: store)
      }
    }
    .frame(minWidth: 640, minHeight: 400)
    .onReceive(NotificationCenter.default.publisher(for: .showTimerTab)) { _ in
      selectedTab = .timer
    }
    .onReceive(NotificationCenter.default.publisher(for: .showTasksTab)) { _ in
      selectedTab = .tasks
    }
    .onReceive(NotificationCenter.default.publisher(for: .showStatsTab)) { _ in
      selectedTab = .stats
    }
    .onReceive(NotificationCenter.default.publisher(for: .browseTasksAndPick)) { _ in
      settings.sidebarVisible = true
      selectedTab = .tasks
    }
  }
}

#Preview {
  MainWindowView(
    engine: SessionEngine(),
    settings: AppSettings(),
    store: SessionStore(),
    selectionStore: TaskSelectionStore(),
    registry: TaskRegistry()
  )
}
