//
//  AppComposition.swift
//  Taskmato
//
//  Created by Richard Klein on 5/2/26.
//

import AppKit
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
  let statsViewModel: StatsViewModel
  let selectionStore: TaskSelectionStore
  let registry: TaskRegistry
  let notifications: NotificationService
  let obsidianProvider: ObsidianProvider
  let localProvider: LocalProvider
  let remindersProvider: RemindersProvider
  let urlHandler: URLSchemeHandler
  let nav: MainNavigation

  /// Constructs every service, registers providers, and wires the phase-ended callback.
  init() {
    let engine = SessionEngine()
    let settings = AppSettings()
    let sessionRepository = Self.makeSessionRepository()
    let store = SessionStore(repository: sessionRepository)
    let selectionStore = TaskSelectionStore()
    let registry = TaskRegistry()
    let notifications = NotificationService(settings: settings)
    let obsidianProvider = ObsidianProvider()
    let localProvider = LocalProvider()
    let remindersProvider = RemindersProvider()
    let statsViewModel = StatsViewModel(
      repository: sessionRepository,
      providerLabel: { [registry] providerID in
        registry.providers.first { $0.id == providerID }?.displayName ?? providerID
      },
      providerTint: { [registry] providerID in
        registry.providers.first { $0.id == providerID }?.tint ?? .gray
      })
    Self.configureNotifications(notifications)
    Self.registerProviders(
      [obsidianProvider, localProvider, remindersProvider], into: registry,
      fallback: localProvider)
    let nav = MainNavigation(settings: settings)
    let urlHandler = URLSchemeHandler(
      registry: registry, selectionStore: selectionStore,
      engine: engine, settings: settings,
      nav: nav
    )
    self.engine = engine
    self.settings = settings
    self.store = store
    self.statsViewModel = statsViewModel
    self.selectionStore = selectionStore
    self.registry = registry
    self.notifications = notifications
    self.obsidianProvider = obsidianProvider
    self.localProvider = localProvider
    self.remindersProvider = remindersProvider
    self.urlHandler = urlHandler
    self.nav = nav
    engine.onPhaseEnded = makePhaseEndedHandler()
  }

  /// Opens the SwiftData session store, trapping if it cannot be created.
  ///
  /// A container failure is unrecoverable — the app cannot function without its session log —
  /// and `AppComposition.init` cannot cleanly throw, so it traps with a clear message.
  private static func makeSessionRepository() -> SwiftDataSessionRepository {
    do {
      let container = try SwiftDataSessionRepository.makeContainer(
        url: SwiftDataSessionRepository.defaultStoreURL())
      return SwiftDataSessionRepository(modelContainer: container)
    } catch {
      fatalError("Unable to open the Taskmato session store: \(error)")
    }
  }

  /// Requests notification authorization at launch and refreshes it on each app activation.
  private static func configureNotifications(_ notifications: NotificationService) {
    Task { await notifications.requestAuthorizationIfNeeded() }
    NotificationCenter.default.addObserver(
      forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
    ) { _ in Task { await notifications.refreshAuthStatus() } }
  }

  /// Registers each provider, enabling `fallback` on first launch when nothing is persisted.
  private static func registerProviders(
    _ providers: [any TaskProvider], into registry: TaskRegistry, fallback: any TaskProvider
  ) {
    for provider in providers { registry.register(provider) }
    if registry.enabledIDs.isEmpty { registry.enable(fallback) }
  }

  /// Records the completed session, fires the phase notification, and advances the timer.
  ///
  /// The engine holds this callback; it moves to `PhaseOrchestrator` at 0.9.0.
  private func makePhaseEndedHandler() -> (SessionPhase, Date, Date, Bool) -> Void {
    { phase, startedAt, endedAt, wasCompleted in
      let session = Session(
        id: UUID(), phase: phase, startedAt: startedAt,
        endedAt: endedAt, wasCompleted: wasCompleted,
        taskRef: self.selectionStore.activeTask?.id,
        taskTitle: self.selectionStore.activeTask?.title
      )
      self.store.append(session)
      self.statsViewModel.recordAppended(session)
      guard wasCompleted else { return }
      self.notifications.send(phase: phase)
      self.engine.focusDuration = self.settings.focusDuration
      self.engine.shortBreakDuration = self.settings.shortBreakDuration
      self.engine.longBreakDuration = self.settings.longBreakDuration
      let next: SessionPhase
      switch phase {
      case .focus:
        next = self.engine.nextBreakPhase(longBreakAfter: self.settings.longBreakAfterSessions)
      case .shortBreak, .longBreak: next = .focus
      }
      if self.settings.autoStartNextPhase {
        self.engine.start(phase: next)
      } else {
        self.engine.enqueuePhase(next)
      }
    }
  }
}
