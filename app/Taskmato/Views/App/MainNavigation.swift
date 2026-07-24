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
/// The SwiftUI `openWindow` environment action is bound onto the model once from the
/// menu-bar popover's `onAppear` via ``bindOpenMainWindow(_:)``; while the app is still an
/// accessory (`LSUIElement`), popover-originated navigation opens the window through the
/// stored action. This plumbing is removed with the lifecycle flip (#444).
@Observable
@MainActor
final class MainNavigation {

  /// The currently selected destination in the main window.
  ///
  /// Assignment forwards task scopes into ``SelectionStore`` and stats scopes into
  /// ``StatsViewModel``; `.timer` forwards nothing.
  var destination: AppDestination {
    didSet { forward(destination) }
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
  @ObservationIgnored private var openMainWindowAction: (() -> Void)?

  /// - Parameters:
  ///   - settings: App settings that persist `sidebarVisible`.
  ///   - selectionStore: The task-scope selection sink that task destinations forward into.
  ///   - statsViewModel: The stats view model whose scope stats destinations forward into.
  init(settings: AppSettings, selectionStore: SelectionStore, statsViewModel: StatsViewModel) {
    self.settings = settings
    self.selectionStore = selectionStore
    self.statsViewModel = statsViewModel
    // Restore the last task scope (Today by default); Timer/Stats are not persisted until #445.
    self.destination = AppDestination(taskSelection: selectionStore.selection) ?? .today
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

  // MARK: - Window binding

  /// Stores the `openWindow` environment action so routing methods can open the main window.
  ///
  /// Call once from the menu-bar popover's `onAppear`. Subsequent calls on popover
  /// re-open overwrite with the same action and are harmless.
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

  /// Opens the main window and switches to the Stats destination at the current scope.
  func showStatsInMainWindow() {
    openMainWindowAction?()
    destination = .stats(statsViewModel.scope)
  }
}
