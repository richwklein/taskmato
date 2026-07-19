//
//  AppFocusedValues.swift
//  Taskmato
//

import SwiftUI

// MARK: - Key types

private struct FocusSearchKey: FocusedValueKey {
  typealias Value = () -> Void
}

private struct AddTaskKey: FocusedValueKey {
  typealias Value = () -> Void
}

private struct ToggleCompletedKey: FocusedValueKey {
  typealias Value = () -> Void
}

private struct ToggleCompletedTitleKey: FocusedValueKey {
  typealias Value = String
}

private struct ToggleCompletedIconKey: FocusedValueKey {
  typealias Value = String
}

private struct TimerToggleKey: FocusedValueKey {
  typealias Value = () -> Void
}

private struct TimerToggleTitleKey: FocusedValueKey {
  typealias Value = String
}

private struct TimerSkipKey: FocusedValueKey {
  typealias Value = () -> Void
}

private struct TimerStopKey: FocusedValueKey {
  typealias Value = () -> Void
}

private struct SelectedTabKey: FocusedValueKey {
  typealias Value = MainTab
}

// MARK: - FocusedValues extensions

extension FocusedValues {

  /// Moves keyboard focus into the Tasks tab search field. Published by ``TasksTabView``.
  var focusSearch: (() -> Void)? {
    get { self[FocusSearchKey.self] }
    set { self[FocusSearchKey.self] = newValue }
  }

  /// Opens the Add Task sheet. Published by ``TasksTabView`` when a writable provider is active.
  var addTask: (() -> Void)? {
    get { self[AddTaskKey.self] }
    set { self[AddTaskKey.self] = newValue }
  }

  /// Toggles the completed tasks section. Published by ``TasksTabView`` when a closable provider is enabled.
  var toggleCompleted: (() -> Void)? {
    get { self[ToggleCompletedKey.self] }
    set { self[ToggleCompletedKey.self] = newValue }
  }

  /// The current label for the completed toggle — "Show Completed" or "Hide Completed".
  var toggleCompletedTitle: String? {
    get { self[ToggleCompletedTitleKey.self] }
    set { self[ToggleCompletedTitleKey.self] = newValue }
  }

  /// The SF Symbol name for the completed toggle icon — matches the corresponding toolbar button.
  var toggleCompletedIcon: String? {
    get { self[ToggleCompletedIconKey.self] }
    set { self[ToggleCompletedIconKey.self] = newValue }
  }

  /// Starts, pauses, or resumes the timer based on current engine state. Published by ``TimerTabView``.
  var timerToggle: (() -> Void)? {
    get { self[TimerToggleKey.self] }
    set { self[TimerToggleKey.self] = newValue }
  }

  /// The current label for the timer toggle action: "Start", "Pause", or "Resume".
  var timerToggleTitle: String? {
    get { self[TimerToggleTitleKey.self] }
    set { self[TimerToggleTitleKey.self] = newValue }
  }

  /// Skips the current phase and advances to the next. Published by ``TimerTabView``.
  var timerSkip: (() -> Void)? {
    get { self[TimerSkipKey.self] }
    set { self[TimerSkipKey.self] = newValue }
  }

  /// Stops the current timer session. Published by ``TimerTabView`` when the engine is not idle.
  var timerStop: (() -> Void)? {
    get { self[TimerStopKey.self] }
    set { self[TimerStopKey.self] = newValue }
  }

  /// The currently selected tab in the main window. Published by ``MainWindowView``.
  var selectedTab: MainTab? {
    get { self[SelectedTabKey.self] }
    set { self[SelectedTabKey.self] = newValue }
  }
}
