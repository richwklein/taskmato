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
/// The `engine.phaseEvents` side-effect cascade is wired here, consumed by `PhaseOrchestrator`.
@MainActor
struct AppComposition {

  let engine: SessionEngine
  let settings: AppSettings
  let timerPresenter: TimerPresenter
  let store: SessionStore
  let statsViewModel: StatsViewModel
  let selectionStore: TaskSelectionStore
  let registry: ProviderRegistry
  let queryService: TaskQueryService
  let sidebarSelection: SelectionStore
  let notifications: NotificationService
  let obsidianProvider: ObsidianProvider
  let localProvider: LocalProvider
  let remindersProvider: RemindersProvider
  let urlHandler: URLSchemeHandler
  let nav: MainNavigation
  let errorPresenter: ErrorPresenter
  let phaseOrchestrator: PhaseOrchestrator
  let focusAttribution: FocusAttribution

  /// Constructs every service, registers providers, and launches the phase-end orchestrator.
  init() {
    let engine = SessionEngine()
    let settingsStore = SettingsStore()
    let settings = AppSettings(store: settingsStore)
    let sessionRepository = Self.makeSessionRepository()
    let store = SessionStore(repository: sessionRepository)
    let selectionStore = TaskSelectionStore(store: settingsStore)
    let registry = ProviderRegistry(store: settingsStore)
    let notifications = NotificationService(settings: settings)
    let obsidianProvider = ObsidianProvider(store: settingsStore)
    let localProvider = LocalProvider()
    let remindersProvider = RemindersProvider(
      store: LiveRemindersEventStore(), settings: settingsStore)
    let statsViewModel = Self.makeStatsViewModel(store: store, registry: registry)
    Self.configureNotifications(notifications)
    Self.registerProviders(
      [obsidianProvider, localProvider, remindersProvider], into: registry,
      fallback: localProvider)
    let queryService = TaskQueryService(registry: registry, sorter: TaskSorter())
    let sidebarSelection = SelectionStore(registry: registry, store: settingsStore)
    let nav = MainNavigation(
      settings: settings, selectionStore: sidebarSelection, statsViewModel: statsViewModel,
      store: settingsStore)
    Self.wireProviderRegistry(registry, sidebarSelection: sidebarSelection, nav: nav)
    // A notification tap opens the main window at Timer (design doc 0008, D5).
    notifications.onNotificationTapped = { nav.showTimerInMainWindow() }
    let errorPresenter = ErrorPresenter()
    let urlHandler = URLSchemeHandler(
      registry: registry, queryService: queryService, selectionStore: selectionStore,
      engine: engine, settings: settings,
      nav: nav, errorPresenter: errorPresenter
    )
    let (phaseOrchestrator, focusAttribution) = Self.makePhaseOrchestrator(
      engine: engine, store: store, settings: settings, selectionStore: selectionStore,
      notifications: notifications)
    Self.wireFocusHandoff(
      engine: engine, settings: settings, nav: nav, selectionStore: selectionStore,
      attribution: focusAttribution)
    self.focusAttribution = focusAttribution
    self.engine = engine
    self.settings = settings
    self.timerPresenter = TimerPresenter(engine: engine, settings: settings)
    self.store = store
    self.statsViewModel = statsViewModel
    self.selectionStore = selectionStore
    self.registry = registry
    self.queryService = queryService
    self.sidebarSelection = sidebarSelection
    self.notifications = notifications
    self.obsidianProvider = obsidianProvider
    self.localProvider = localProvider
    self.remindersProvider = remindersProvider
    self.urlHandler = urlHandler
    self.nav = nav
    self.errorPresenter = errorPresenter
    self.phaseOrchestrator = phaseOrchestrator
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

  /// Builds the stats view model, resolving provider display names and tints through `registry`.
  private static func makeStatsViewModel(
    store: SessionStore, registry: ProviderRegistry
  ) -> StatsViewModel {
    StatsViewModel(
      store: store,
      providerLabel: { [registry] providerID in
        registry.providers.first { $0.id.rawValue == providerID }?.displayName ?? providerID
      },
      providerTint: { [registry] providerID in
        registry.providers.first { $0.id.rawValue == providerID }?.tint ?? .gray
      })
  }

  /// Revalidates the sidebar selection and reconciles the task-scope destination whenever a
  /// provider's enabled state changes (design doc 0008, D9).
  private static func wireProviderRegistry(
    _ registry: ProviderRegistry, sidebarSelection: SelectionStore, nav: MainNavigation
  ) {
    registry.onProviderStateChanged = { [weak sidebarSelection, weak nav] in
      sidebarSelection?.validateSelection()
      nav?.reconcileTaskScope()
    }
  }

  /// Requests notification authorization at launch and refreshes it on each app activation.
  private static func configureNotifications(_ notifications: NotificationService) {
    Task { await notifications.requestAuthorizationIfNeeded() }
    NotificationCenter.default.addObserver(
      forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
    ) { _ in Task { await notifications.refreshAuthStatus() } }
  }

  /// Builds the phase-end orchestrator (and its ``FocusAttribution`` collaborator) and
  /// launches the orchestrator, fire-and-forget, for the app's lifetime.
  private static func makePhaseOrchestrator(
    engine: SessionEngine, store: SessionStore, settings: AppSettings,
    selectionStore: TaskSelectionStore, notifications: NotificationService
  ) -> (orchestrator: PhaseOrchestrator, attribution: FocusAttribution) {
    let attribution = FocusAttribution()
    let orchestrator = PhaseOrchestrator(
      events: engine.phaseEvents, engine: engine, store: store, settings: settings,
      selectionStore: selectionStore, notifications: notifications, attribution: attribution)
    Task { await orchestrator.run() }
    return (orchestrator, attribution)
  }

  /// Wires the two focus-handoff callbacks onto `selectionStore` (D4/D9 of design doc 0010): a
  /// task change appends a slice to the live focus phase's attribution log, and a genuine
  /// handoff continuation auto-resumes when `autoStartNextPhase` is on.
  private static func wireFocusHandoff(
    engine: SessionEngine, settings: AppSettings, nav: MainNavigation,
    selectionStore: TaskSelectionStore, attribution: FocusAttribution
  ) {
    selectionStore.onActiveTaskChanged = { [weak engine] task in
      guard let engine else { return }
      attribution.taskChanged(to: task, consumedSeconds: engine.consumedFocusSeconds)
    }
    selectionStore.onContinuationSelect = { [weak engine, weak nav] in
      guard settings.autoStartNextPhase else { return }
      engine?.resume()
      nav?.showTimerInMainWindow()
    }
  }

  /// Registers each provider, enabling `fallback` on first launch when nothing is persisted.
  private static func registerProviders(
    _ providers: [any TaskProvider], into registry: ProviderRegistry, fallback: any TaskProvider
  ) {
    for provider in providers { registry.register(provider) }
    if registry.enabledIDs.isEmpty { registry.enable(fallback) }
  }
}
