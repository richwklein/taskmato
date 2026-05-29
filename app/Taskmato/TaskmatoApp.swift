//
//  TaskmatoApp.swift
//  Taskmato
//
//  Created by Richard Klein on 5/2/26.
//

import AppKit
import SwiftUI

/// Applies the dock icon activation policy once the application has fully launched,
/// and forwards URL scheme events directly to ``URLSchemeHandler``.
///
/// `NSApp.setActivationPolicy` must not be called during `App.init()` — the launch
/// sequence is incomplete at that point and the call traps on restart. Deferring to
/// `applicationDidFinishLaunching` is the documented safe window.
///
/// URL events are handled here rather than via `.onOpenURL` on SwiftUI views because
/// `MenuBarExtra` content is not in the main window responder chain and misses URL events
/// when the popover is collapsed.
final class AppDelegate: NSObject, NSApplicationDelegate {

  /// Injected by `TaskmatoApp.init()`. Called from `applicationWillFinishLaunching`,
  /// which fires before the system delivers any queued `taskmato://` Apple events —
  /// guaranteeing the handler is wired before the first URL arrives.
  var bootstrap: (() -> Void)?

  private(set) var urlHandler: URLSchemeHandler?

  func applicationWillFinishLaunching(_ notification: Notification) {
    bootstrap?()
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    if UserDefaults.standard.bool(forKey: "showDockIcon") {
      NSApp.setActivationPolicy(.regular)
    }
  }

  func application(_ application: NSApplication, open urls: [URL]) {
    guard let urlHandler else { return }
    for url in urls {
      Task { @MainActor in
        await urlHandler.handle(url)
      }
    }
  }

  /// Called by the bootstrap closure to complete dependency injection.
  fileprivate func wire(urlHandler: URLSchemeHandler) {
    self.urlHandler = urlHandler
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
  @State private var localProvider: LocalProvider
  @State private var urlHandler: URLSchemeHandler

  init() {
    let engine = SessionEngine()
    let settings = AppSettings()
    let store = SessionStore()
    let selectionStore = TaskSelectionStore()
    let registry = TaskRegistry()
    let notifications = NotificationService()
    let sounds = SoundService()
    let obsidianProvider = ObsidianProvider()
    let localProvider = LocalProvider()
    registry.register(obsidianProvider)
    registry.register(localProvider)
    // Auto-enable on first launch before any provider state is persisted.
    if registry.enabledIDs.isEmpty { registry.enable(localProvider) }
    let urlHandler = URLSchemeHandler(
      registry: registry,
      selectionStore: selectionStore,
      engine: engine,
      settings: settings,
      localProvider: localProvider
    )

    engine.onPhaseEnded = { phase, startedAt, endedAt, wasCompleted in
      store.append(
        Session(
          id: UUID(),
          phase: phase,
          startedAt: startedAt,
          endedAt: endedAt,
          wasCompleted: wasCompleted,
          taskRef: selectionStore.activeTask?.id,
          taskTitle: selectionStore.activeTask?.title
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
    _localProvider = State(initialValue: localProvider)
    _urlHandler = State(initialValue: urlHandler)

    // Capture the delegate so the closure doesn't retain _appDelegate's storage.
    // App.init() runs once; this local IS the @State-managed handler for the app's lifetime.
    let appDel = _appDelegate.wrappedValue
    appDel.bootstrap = { appDel.wire(urlHandler: urlHandler) }
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
      .confirmationDialog(
        "Multiple tasks match — which one?",
        isPresented: Binding(
          get: { urlHandler.pendingDisambiguation != nil },
          set: { if !$0 { urlHandler.pendingDisambiguation = nil } }
        ),
        titleVisibility: .visible,
        presenting: urlHandler.pendingDisambiguation
      ) { matches in
        ForEach(matches.prefix(4)) { task in
          Button(task.title) {
            selectionStore.select(task)
            urlHandler.pendingDisambiguation = nil
            NotificationCenter.default.post(name: .showTimerTab, object: nil)
          }
        }
        if let params = urlHandler.pendingAdHocParams {
          Button("Create new \"\(params.title)\"") {
            let task = urlHandler.makeAdHocTask(from: params)
            selectionStore.select(task)
            urlHandler.pendingDisambiguation = nil
            NotificationCenter.default.post(name: .showTimerTab, object: nil)
          }
        }
        Button("Cancel", role: .cancel) {
          urlHandler.pendingDisambiguation = nil
          urlHandler.pendingAdHocParams = nil
        }
      }
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
