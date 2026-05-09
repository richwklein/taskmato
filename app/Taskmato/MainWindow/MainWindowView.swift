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

  var body: some View {
    TabView {
      Tab("Timer", systemImage: "timer") {
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

      Tab("Tasks", systemImage: "checklist") {
        TasksTabView()
      }

      Tab("Stats", systemImage: "chart.bar") {
        StatsTabView()
      }
    }
    .frame(minWidth: 480, minHeight: 400)
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
