//
//  AppComposition.swift
//  Taskmato
//
//  Created by Richard Klein on 5/2/26.
//

import AppKit
import Foundation
import SwiftData

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
  let destinationResolver: TaskDestinationResolver
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
  let activeTaskReconciler: ActiveTaskReconciler
  let activeTaskLiveObserver: ActiveTaskLiveObserver

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
    let localProvider = LocalProvider(repository: Self.makeLocalRepository())
    let remindersProvider = RemindersProvider(
      store: LiveRemindersEventStore(), settings: settingsStore)
    let statsViewModel = Self.makeStatsViewModel(store: store, registry: registry)
    Self.configureNotifications(notifications)
    Self.registerProviders(
      [obsidianProvider, localProvider, remindersProvider], into: registry,
      fallback: localProvider)
    let queryService = TaskQueryService(registry: registry, sorter: TaskSorter())
    let destinationResolver = TaskDestinationResolver(registry: registry, settings: settings)
    let sidebarSelection = SelectionStore(registry: registry, store: settingsStore)
    let nav = MainNavigation(
      settings: settings, selectionStore: sidebarSelection, statsViewModel: statsViewModel,
      store: settingsStore)
    // A notification tap opens the main window at Timer (design doc 0008, D5).
    notifications.onNotificationTapped = { nav.showTimerInMainWindow() }
    let errorPresenter = ErrorPresenter()
    let urlHandler = URLSchemeHandler(
      registry: registry, queryService: queryService, selectionStore: selectionStore,
      engine: engine, settings: settings,
      nav: nav, errorPresenter: errorPresenter, destinationResolver: destinationResolver
    )
    let runtime = Self.makeRuntime(
      RuntimeInputs(
        engine: engine, store: store, settings: settings, selectionStore: selectionStore,
        registry: registry, sidebarSelection: sidebarSelection, nav: nav,
        notifications: notifications, errorPresenter: errorPresenter))
    self.activeTaskLiveObserver = runtime.activeTaskReconciliation.liveObserver
    self.activeTaskReconciler = runtime.activeTaskReconciliation.reconciler
    self.focusAttribution = runtime.focusAttribution
    self.engine = engine
    self.settings = settings
    self.timerPresenter = TimerPresenter(engine: engine, settings: settings)
    self.store = store
    self.statsViewModel = statsViewModel
    self.selectionStore = selectionStore
    self.registry = registry
    self.queryService = queryService
    self.destinationResolver = destinationResolver
    self.sidebarSelection = sidebarSelection
    self.notifications = notifications
    self.obsidianProvider = obsidianProvider
    self.localProvider = localProvider
    self.remindersProvider = remindersProvider
    self.urlHandler = urlHandler
    self.nav = nav
    self.errorPresenter = errorPresenter
    self.phaseOrchestrator = runtime.phaseOrchestrator
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

  /// Opens the SwiftData local task store, trapping if it cannot be created, then runs the
  /// one-shot JSON migration before any provider touches the container.
  ///
  /// The migration must run before ``LocalProvider`` is constructed — its async `reload()`
  /// would otherwise be free to normalize an empty store over data the migration hasn't
  /// imported yet.
  private static func makeLocalRepository() -> SwiftDataLocalTaskRepository {
    let container: ModelContainer
    do {
      container = try SwiftDataLocalTaskRepository.makeContainer(
        url: SwiftDataLocalTaskRepository.defaultStoreURL())
    } catch {
      fatalError("Unable to open the Taskmato local task store: \(error)")
    }
    LocalStoreJSONMigrator.migrateIfNeeded(
      jsonURL: JSONLocalTaskRepository.defaultFileURL(), into: container)
    return SwiftDataLocalTaskRepository(modelContainer: container)
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

  /// Revalidates the sidebar selection, reconciles the task-scope destination, and reconciles
  /// the active task whenever a provider's enabled state or list cache changes (design doc 0008,
  /// D9; issue #547 for the active-task leg). One explicit closure rather than a chain of
  /// independent wiring calls, so a future caller can't accidentally overwrite an earlier leg by
  /// assigning `onProviderStateChanged` again instead of composing onto it.
  private static func wireProviderRegistry(
    _ registry: ProviderRegistry, sidebarSelection side: SelectionStore, nav: MainNavigation,
    reconciler rec: ActiveTaskReconciler, liveObserver live: ActiveTaskLiveObserver
  ) {
    registry.onProviderStateChanged = { [weak side, weak nav, weak rec, weak live] providerID in
      side?.validateSelection()
      nav?.reconcileTaskScope()
      live?.reconcileSubscriptions()
      guard let rec else { return }
      Task { await rec.reconcile(changedProviderID: providerID) }
    }
  }

  /// Builds and wires active-task reconciliation on registry reloads and provider live pushes.
  private static func wireActiveTaskReconciliation(
    registry: ProviderRegistry, selectionStore: TaskSelectionStore,
    runtime: (engine: SessionEngine, attribution: FocusAttribution),
    navigation: (sidebarSelection: SelectionStore, nav: MainNavigation),
    errorPresenter: ErrorPresenter
  ) -> (reconciler: ActiveTaskReconciler, liveObserver: ActiveTaskLiveObserver) {
    let reconciler = ActiveTaskReconciler(
      registry: registry, selectionStore: selectionStore, engine: runtime.engine,
      attribution: runtime.attribution, errorPresenter: errorPresenter)
    let liveObserver = ActiveTaskLiveObserver(registry: registry, reconciler: reconciler)
    Self.wireProviderRegistry(
      registry, sidebarSelection: navigation.sidebarSelection, nav: navigation.nav,
      reconciler: reconciler, liveObserver: liveObserver)
    liveObserver.start()
    return (reconciler, liveObserver)
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
  ///
  /// `inputs.registry` resolves each focus slice's owning provider's label and tint, snapshotted
  /// onto the slice at close (ADR-0010, D4).
  private static func makePhaseOrchestrator(
    _ inputs: RuntimeInputs
  ) -> (orchestrator: PhaseOrchestrator, attribution: FocusAttribution) {
    let registry = inputs.registry
    let attribution = FocusAttribution(cosmetics: { [registry] providerID in
      guard let provider = registry.providers.first(where: { $0.id == providerID }) else {
        return nil
      }
      return (provider.displayName, provider.tint)
    })
    let orchestrator = PhaseOrchestrator(
      events: inputs.engine.phaseEvents, engine: inputs.engine, store: inputs.store,
      settings: inputs.settings, selectionStore: inputs.selectionStore,
      notifications: inputs.notifications, attribution: attribution)
    Task { await orchestrator.run() }
    return (orchestrator, attribution)
  }

  /// Builds the phase and active-task runtime services that share registry and navigation wiring.
  private static func makeRuntime(_ inputs: RuntimeInputs) -> RuntimeServices {
    let (phaseOrchestrator, focusAttribution) = Self.makePhaseOrchestrator(inputs)
    Self.wireFocusHandoff(
      engine: inputs.engine, settings: inputs.settings, nav: inputs.nav,
      selectionStore: inputs.selectionStore,
      attribution: focusAttribution)
    let activeTaskReconciliation = Self.wireActiveTaskReconciliation(
      registry: inputs.registry, selectionStore: inputs.selectionStore,
      runtime: (engine: inputs.engine, attribution: focusAttribution),
      navigation: (sidebarSelection: inputs.sidebarSelection, nav: inputs.nav),
      errorPresenter: inputs.errorPresenter)
    return RuntimeServices(
      phaseOrchestrator: phaseOrchestrator, focusAttribution: focusAttribution,
      activeTaskReconciliation: activeTaskReconciliation)
  }

  private struct RuntimeInputs {
    let engine: SessionEngine
    let store: SessionStore
    let settings: AppSettings
    let selectionStore: TaskSelectionStore
    let registry: ProviderRegistry
    let sidebarSelection: SelectionStore
    let nav: MainNavigation
    let notifications: NotificationService
    let errorPresenter: ErrorPresenter
  }

  private struct RuntimeServices {
    let phaseOrchestrator: PhaseOrchestrator
    let focusAttribution: FocusAttribution
    let activeTaskReconciliation:
      (reconciler: ActiveTaskReconciler, liveObserver: ActiveTaskLiveObserver)
  }

  /// Wires the three focus-handoff callbacks onto `selectionStore` (D4/D9 of design doc 0010,
  /// D-f of "stage the next focus"): a task change appends a slice to the live focus phase's
  /// attribution log, a genuine handoff continuation auto-resumes when `autoStartNextPhase` is
  /// on, and a staged-task promotion (the complete gesture only) resumes the same way but
  /// without navigating — the popover's two-line readout already shows the promoted task.
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
    selectionStore.onStagedPromotion = { [weak engine] in
      guard settings.autoStartNextPhase else { return }
      engine?.resume()
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
