//
//  AppComposition.swift
//  Taskmato
//
//  Created by Richard Klein on 5/2/26.
//

import Foundation

/// The composition root for Taskmato — constructs every service and exposes
/// them as immutable properties for injection into the scene hierarchy.
///
/// `TaskmatoApp` holds one `@State` instance and passes slices to each scene.
/// The `engine.onPhaseEnded` side-effect cascade is wired here; it will move
/// to `PhaseOrchestrator` at 0.9.0.
@MainActor
struct AppComposition {

  let engine: SessionEngine
  let settings: AppSettings
  let store: SessionStore
  let selectionStore: TaskSelectionStore
  let registry: TaskRegistry
  let notifications: NotificationService
  let sounds: SoundService
  let obsidianProvider: ObsidianProvider
  let localProvider: LocalProvider
  let remindersProvider: RemindersProvider
  let urlHandler: URLSchemeHandler
  let nav: MainNavigation

  /// Constructs every service, registers providers, and wires the phase-ended callback.
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
    let remindersProvider = RemindersProvider()
    registry.register(obsidianProvider)
    registry.register(localProvider)
    registry.register(remindersProvider)
    // Auto-enable on first launch before any provider state is persisted.
    if registry.enabledIDs.isEmpty { registry.enable(localProvider) }
    let nav = MainNavigation(settings: settings)
    let urlHandler = URLSchemeHandler(
      registry: registry, selectionStore: selectionStore,
      engine: engine, settings: settings, localProvider: localProvider,
      nav: nav
    )
    engine.onPhaseEnded = { phase, startedAt, endedAt, wasCompleted in
      store.append(
        Session(
          id: UUID(), phase: phase, startedAt: startedAt,
          endedAt: endedAt, wasCompleted: wasCompleted,
          taskRef: selectionStore.activeTask?.id,
          taskTitle: selectionStore.activeTask?.title
        ))
      guard wasCompleted else { return }
      if settings.soundEnabled { sounds.play() }
      if settings.notificationsEnabled { notifications.send(phase: phase) }
      engine.focusDuration = settings.focusDuration
      engine.shortBreakDuration = settings.shortBreakDuration
      engine.longBreakDuration = settings.longBreakDuration
      let next: SessionPhase
      switch phase {
      case .focus:
        next = engine.nextBreakPhase(longBreakAfter: settings.longBreakAfterSessions)
      case .shortBreak, .longBreak: next = .focus
      }
      if settings.autoStartNextPhase {
        engine.start(phase: next)
      } else {
        engine.enqueuePhase(next)
      }
    }
    self.engine = engine
    self.settings = settings
    self.store = store
    self.selectionStore = selectionStore
    self.registry = registry
    self.notifications = notifications
    self.sounds = sounds
    self.obsidianProvider = obsidianProvider
    self.localProvider = localProvider
    self.remindersProvider = remindersProvider
    self.urlHandler = urlHandler
    self.nav = nav
  }
}
