//
//  MainNavigation.swift
//  Taskmato
//

import Foundation
import Observation

/// Observable navigation model for the main application window.
///
/// `MainNavigation` is the single authority for tab selection and sidebar visibility.
/// The SwiftUI `openWindow` environment action is bound onto the model once from the
/// menu-bar popover's `onAppear` via ``bindOpenMainWindow(_:)``; all subsequent
/// window-open requests use the stored action instead of flowing through the scene graph.
@Observable
@MainActor
final class MainNavigation {

  /// The currently selected tab in the main window.
  var selectedTab: MainTab = .tasks

  /// Whether the provider/list sidebar column is visible in the Tasks tab.
  ///
  /// Reads and writes forward to ``AppSettings/sidebarVisible`` so `UserDefaults`
  /// remains the single source of truth for persistence.
  var sidebarVisible: Bool {
    get { settings.sidebarVisible }
    set { settings.sidebarVisible = newValue }
  }

  private let settings: AppSettings
  private var openMainWindowAction: (() -> Void)?

  /// - Parameter settings: The app settings instance that persists `sidebarVisible`.
  init(settings: AppSettings) {
    self.settings = settings
  }

  /// Stores the `openWindow` environment action so routing methods can open the main window.
  ///
  /// Call once from the menu-bar popover's `onAppear`. Subsequent calls on popover
  /// re-open overwrite with the same action and are harmless.
  func bindOpenMainWindow(_ action: @escaping () -> Void) {
    openMainWindowAction = action
  }

  /// Switches to the Timer tab without opening the main window.
  func showTimer() { selectedTab = .timer }

  /// Switches to the Tasks tab without opening the main window.
  func showTasks() { selectedTab = .tasks }

  /// Switches to the Stats tab without opening the main window.
  func showStats() { selectedTab = .stats }

  /// Expands the provider sidebar and switches to the Tasks tab.
  func browseTasksAndPick() {
    sidebarVisible = true
    selectedTab = .tasks
  }

  /// Opens the main window without changing the selected tab.
  func openMainWindow() { openMainWindowAction?() }

  /// Opens the main window and switches to the Timer tab.
  func showTimerInMainWindow() {
    openMainWindowAction?()
    selectedTab = .timer
  }

  /// Opens the main window and switches to the Stats tab.
  func showStatsInMainWindow() {
    openMainWindowAction?()
    selectedTab = .stats
  }
}
