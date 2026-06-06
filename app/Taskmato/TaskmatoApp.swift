//
//  TaskmatoApp.swift
//  Taskmato
//
//  Created by Richard Klein on 5/2/26.
//

import AppKit
import SwiftUI

@main
struct TaskmatoApp: App {

  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  @State private var composition: AppComposition

  init() {
    let composition = AppComposition()
    _composition = State(initialValue: composition)
    let appDel = _appDelegate.wrappedValue
    appDel.bootstrap = { appDel.wire(urlHandler: composition.urlHandler) }
  }

  var body: some Scene {
    MenuBarExtra {
      TimerView(
        engine: composition.engine,
        settings: composition.settings,
        store: composition.store,
        selectionStore: composition.selectionStore,
        registry: composition.registry,
        nav: composition.nav,
        nextStartPhase: composition.engine.queuedPhase ?? .focus,
        nextBreakPhase: composition.engine.nextBreakPhase(
          longBreakAfter: composition.settings.longBreakAfterSessions)
      )
      .confirmationDialog(
        "Multiple tasks match — which one?",
        isPresented: Binding(
          get: { composition.urlHandler.pendingDisambiguation != nil },
          set: { if !$0 { composition.urlHandler.pendingDisambiguation = nil } }
        ),
        titleVisibility: .visible,
        presenting: composition.urlHandler.pendingDisambiguation
      ) { matches in
        ForEach(matches.prefix(4)) { task in
          Button(task.title) {
            composition.selectionStore.select(task)
            composition.urlHandler.pendingDisambiguation = nil
            composition.nav.showTimerInMainWindow()
          }
        }
        if let params = composition.urlHandler.pendingAdHocParams {
          Button("Create new \"\(params.title)\"") {
            Task {
              let task = await composition.urlHandler.makeAdHocTask(from: params)
              composition.selectionStore.select(task)
              composition.urlHandler.pendingDisambiguation = nil
              composition.nav.showTimerInMainWindow()
            }
          }
        }
        Button("Cancel", role: .cancel) {
          composition.urlHandler.pendingDisambiguation = nil
          composition.urlHandler.pendingAdHocParams = nil
        }
      }
    } label: {
      HStack(spacing: 4) {
        Image("MenuIcon")
        Text(menuBarLabel)
      }
    }
    .menuBarExtraStyle(.window)

    Window(Bundle.main.appName, id: "main") {
      MainWindowView(
        engine: composition.engine,
        settings: composition.settings,
        store: composition.store,
        selectionStore: composition.selectionStore,
        registry: composition.registry,
        nav: composition.nav
      )
    }
    .defaultSize(width: 480, height: 520)
    .windowResizability(.contentMinSize)

    Settings {
      SettingsView(
        settings: composition.settings,
        selectionStore: composition.selectionStore,
        registry: composition.registry
      )
    }
    .windowResizability(.contentSize)
  }

  /// Formats the active or idle time as `"MM:SS"` for display in the menu bar.
  private var menuBarLabel: String {
    let seconds: Int
    if case .idle = composition.engine.state {
      let phase = composition.engine.queuedPhase ?? SessionPhase.focus
      switch phase {
      case .focus: seconds = Int(composition.settings.focusDuration)
      case .shortBreak: seconds = Int(composition.settings.shortBreakDuration)
      case .longBreak: seconds = Int(composition.settings.longBreakDuration)
      }
    } else {
      seconds = Int(composition.engine.timeRemaining)
    }
    return String(format: "%02d:%02d", seconds / 60, seconds % 60)
  }
}
