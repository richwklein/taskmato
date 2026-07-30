//
//  MainNavigation.swift
//  Taskmato
//

import Foundation
import Observation

/// Observable navigation model for the main application window.
///
/// `MainNavigation` is the single authority for the current ``AppDestination`` and sidebar
/// visibility. It forwards task-scope destinations (`.today` / `.list`) one-way into the
/// ``SelectionStore`` sink and stats destinations into ``StatsViewModel/scope``, so the
/// task-query and stats layers never learn about each other's surfaces (design doc 0008, D4).
///
/// The SwiftUI `openWindow` environment action is bound onto the model once from the main
/// window's `onAppear` via ``bindOpenMainWindow(_:)``. The main window is the primary surface
/// and owns this plumbing; external activations (notification tap, `taskmato://`) and the
/// popover route through the stored action to reopen the window when it has been closed.
@Observable
@MainActor
final class MainNavigation {

  /// The currently selected destination in the main window.
  ///
  /// Assignment forwards task scopes into ``SelectionStore`` and stats scopes into
  /// ``StatsViewModel``; `.timer` forwards nothing.
  var destination: AppDestination {
    didSet {
      forward(destination)
      persistDestination()
    }
  }

  /// Whether the sidebar column is visible in the root split view.
  ///
  /// Reads and writes forward to ``AppSettings/sidebarVisible`` so `UserDefaults`
  /// remains the single source of truth for persistence.
  var sidebarVisible: Bool {
    get { settings.sidebarVisible }
    set { settings.sidebarVisible = newValue }
  }

  @ObservationIgnored private let settings: AppSettings
  @ObservationIgnored private let selectionStore: SelectionStore
  @ObservationIgnored private let statsViewModel: StatsViewModel
  @ObservationIgnored private let store: SettingsStore
  @ObservationIgnored private var openMainWindowAction: (() -> Void)?

  /// - Parameters:
  ///   - settings: App settings that persist `sidebarVisible`.
  ///   - selectionStore: The task-scope selection sink that task destinations forward into.
  ///   - statsViewModel: The stats view model whose scope stats destinations forward into.
  ///   - store: The settings store for the persisted destination. Override in tests.
  init(
    settings: AppSettings, selectionStore: SelectionStore, statsViewModel: StatsViewModel,
    store: SettingsStore = SettingsStore()
  ) {
    self.settings = settings
    self.selectionStore = selectionStore
    self.statsViewModel = statsViewModel
    self.store = store
    // Restore the last surface (design doc 0008, D9). `didSet` does not fire during `init`, so
    // the Stats scope is forwarded explicitly; the task scope is owned by `SelectionStore`.
    switch Self.decodePersistedDestination(from: store) {
    case .timer:
      self.destination = .timer
    case .stats(let scope):
      statsViewModel.scope = scope
      self.destination = .stats(scope)
    case .tasks, .none:
      self.destination = AppDestination(taskSelection: selectionStore.selection) ?? .today
    }
  }

  /// Forwards a destination into the sink that owns its state, for task and stats scopes.
  private func forward(_ destination: AppDestination) {
    if let taskSelection = destination.taskSelection {
      selectionStore.select(taskSelection)
    }
    if case .stats(let scope) = destination {
      statsViewModel.scope = scope
    }
  }

  /// Mirrors ``SelectionStore``'s validated selection back into ``destination`` after its
  /// vanished-list cascade, so a persisted list that no longer exists falls back to Today.
  ///
  /// A no-op unless the current destination is a task scope, and idempotent when the two are
  /// already in sync — safe to call on every `onProviderStateChanged` (design doc 0008, D9).
  func reconcileTaskScope() {
    guard destination.taskSelection != nil else { return }
    let mirrored = AppDestination(taskSelection: selectionStore.selection) ?? .today
    if mirrored != destination { destination = mirrored }
  }

  // MARK: - Destination persistence

  /// The last surface, persisted to restore navigation on the next launch. The task scope is
  /// owned by ``SelectionStore``, so only the surface discriminator is stored here.
  private enum PersistedDestination: Codable {
    /// The Timer surface.
    case timer
    /// Any task scope; the specific list/Today is restored from ``SelectionStore``.
    case tasks
    /// The Stats surface at a specific scope.
    case stats(StatScope)
  }

  private static func decodePersistedDestination(
    from store: SettingsStore
  ) -> PersistedDestination? {
    store.value(forKey: SettingsStore.Keys.shellDestination, as: PersistedDestination.self)
  }

  private func persistDestination() {
    let persisted: PersistedDestination
    switch destination {
    case .timer: persisted = .timer
    case .today, .list: persisted = .tasks
    case .stats(let scope): persisted = .stats(scope)
    }
    store.setValue(persisted, forKey: SettingsStore.Keys.shellDestination)
  }

  // MARK: - Window binding

  /// Stores the `openWindow` environment action so routing methods can open the main window.
  ///
  /// Call once from the main window's `onAppear`. Subsequent calls overwrite with the same
  /// action and are harmless. The stored `OpenWindowAction` remains valid after the window
  /// closes, so it can reopen the window on a warm-start external activation.
  func bindOpenMainWindow(_ action: @escaping () -> Void) {
    openMainWindowAction = action
  }

  /// Opens the main window without changing the destination.
  func openMainWindow() { openMainWindowAction?() }

  // MARK: - In-window routing

  /// Switches to the Timer destination.
  func showTimer() { destination = .timer }

  /// Switches to the last task-scope destination, falling back to Today.
  func showTasks() {
    destination = AppDestination(taskSelection: selectionStore.selection) ?? .today
  }

  /// Switches to the Stats destination at the current scope.
  func showStats() { destination = .stats(statsViewModel.scope) }

  // MARK: - Window-opening routing (popover / external activation)

  /// Opens the main window and switches to the Timer destination.
  func showTimerInMainWindow() {
    openMainWindowAction?()
    destination = .timer
  }

  /// Opens the main window and switches to the last task-scope destination, falling back to Today.
  func showTasksInMainWindow() {
    openMainWindowAction?()
    showTasks()
  }

  /// Opens the main window and switches to the Stats destination at the current scope.
  func showStatsInMainWindow() {
    openMainWindowAction?()
    destination = .stats(statsViewModel.scope)
  }
}
