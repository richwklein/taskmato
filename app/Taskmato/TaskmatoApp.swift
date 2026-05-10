//
//  TaskmatoApp.swift
//  Taskmato
//
//  Created by Richard Klein on 5/2/26.
//

import AppKit
import SwiftUI

/// Applies the dock icon activation policy once the application has fully launched.
///
/// `NSApp.setActivationPolicy` must not be called during `App.init()` — the launch
/// sequence is incomplete at that point and the call traps on restart. Deferring to
/// `applicationDidFinishLaunching` is the documented safe window.
final class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    if UserDefaults.standard.bool(forKey: "showDockIcon") {
      NSApp.setActivationPolicy(.regular)
    }
  }
}

@main
struct TaskmatoApp: App {

  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  @State private var engine: SessionEngine
  @State private var settings: AppSettings
  @State private var store: SessionStore
  @State private var selectionStore: TaskSelectionStore
  @State private var registry: TaskRegistry
  @State private var notifications: NotificationService
  @State private var sounds: SoundService
  @State private var obsidianProvider: ObsidianProvider

  init() {
    let engine = SessionEngine()
    let settings = AppSettings()
    let store = SessionStore()
    let selectionStore = TaskSelectionStore()
    let registry = TaskRegistry()
    let notifications = NotificationService()
    let sounds = SoundService()
    let obsidianProvider = ObsidianProvider()
    registry.register(obsidianProvider)

    engine.onPhaseEnded = { phase, startedAt, endedAt, wasCompleted in
      store.append(
        Session(
          id: UUID(),
          phase: phase,
          startedAt: startedAt,
          endedAt: endedAt,
          wasCompleted: wasCompleted,
          taskRef: selectionStore.activeTask?.id
        ))
      if wasCompleted {
        if settings.soundEnabled { sounds.play() }
        if settings.notificationsEnabled { notifications.send(phase: phase) }
        engine.focusDuration = settings.focusDuration
        engine.shortBreakDuration = settings.shortBreakDuration
        engine.longBreakDuration = settings.longBreakDuration
        let next: SessionPhase
        switch phase {
        case .focus: next = engine.nextBreakPhase(longBreakAfter: settings.longBreakAfterSessions)
        case .shortBreak, .longBreak: next = .focus
        }
        if settings.autoStartNextPhase {
          engine.start(phase: next)
        } else {
          engine.enqueuePhase(next)
        }
      }
    }

    _engine = State(initialValue: engine)
    _settings = State(initialValue: settings)
    _store = State(initialValue: store)
    _selectionStore = State(initialValue: selectionStore)
    _registry = State(initialValue: registry)
    _notifications = State(initialValue: notifications)
    _sounds = State(initialValue: sounds)
    _obsidianProvider = State(initialValue: obsidianProvider)
  }

  var body: some Scene {
    MenuBarExtra(menuBarLabel) {
      TimerView(
        engine: engine,
        settings: settings,
        store: store,
        selectionStore: selectionStore,
        registry: registry,
        nextStartPhase: engine.queuedPhase ?? .focus,
        nextBreakPhase: engine.nextBreakPhase(longBreakAfter: settings.longBreakAfterSessions)
      )
    }
    .menuBarExtraStyle(.window)

    Window(Bundle.main.appName, id: "main") {
      MainWindowView(
        engine: engine,
        settings: settings,
        store: store,
        selectionStore: selectionStore,
        registry: registry
      )
    }
    .defaultSize(width: 480, height: 520)
    .windowResizability(.contentMinSize)

    Settings {
      SettingsView(
        settings: settings,
        selectionStore: selectionStore,
        registry: registry,
        obsidianProvider: obsidianProvider
      )
    }
    .windowResizability(.contentSize)
  }

  /// Formats the active or idle time as `"🍅 MM:SS"` for display in the menu bar.
  private var menuBarLabel: String {
    let seconds: Int
    if case .idle = engine.state {
      let phase = engine.queuedPhase ?? SessionPhase.focus
      switch phase {
      case .focus: seconds = Int(settings.focusDuration)
      case .shortBreak: seconds = Int(settings.shortBreakDuration)
      case .longBreak: seconds = Int(settings.longBreakDuration)
      }
    } else {
      seconds = Int(engine.timeRemaining)
    }
    return "🍅 \(String(format: "%02d:%02d", seconds / 60, seconds % 60))"
  }
}
