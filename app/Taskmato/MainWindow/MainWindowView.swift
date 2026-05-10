//
//  MainWindowView.swift
//  Taskmato
//

import SwiftUI

/// The root view for the main application window, hosting three-tab navigation.
///
/// Tabs: Timer (primary), Tasks (P1/P3), Stats (P6).
/// Settings opens in a separate window via the toolbar button or ⌘,.
struct MainWindowView: View {

  var engine: SessionEngine
  var settings: AppSettings
  var store: SessionStore
  var selectionStore: TaskSelectionStore
  var registry: TaskRegistry

  @Environment(\.openSettings) private var openSettings
  @State private var selectedTab: Int = 0

  var body: some View {
    TabView(selection: $selectedTab) {
      Tab("Timer", systemImage: "timer", value: 0) {
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

      Tab("Tasks", systemImage: "checklist", value: 1) {
        TasksTabView(
          selectionStore: selectionStore,
          registry: registry,
          selectedTab: $selectedTab
        )
      }

      Tab("Stats", systemImage: "chart.bar", value: 2) {
        StatsTabView()
      }
    }
    .frame(minWidth: 480, minHeight: 400)
    .onReceive(NotificationCenter.default.publisher(for: .showTasksTab)) { _ in
      selectedTab = 1
    }
    .toolbar {
      ToolbarItem(placement: .automatic) {
        Button {
          openSettings()
        } label: {
          Label("Settings", systemImage: "gearshape")
        }
        .help("Open Settings (⌘,)")
      }
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
