//
//  TaskSelectionStore.swift
//  Taskmato
//

import Foundation
import Observation

/// Tracks the currently selected task and a per-provider recents list.
///
/// The active task and recents are persisted to `UserDefaults` so selections
/// survive app relaunch. Recents are capped at 10 entries per provider, with
/// the most recently selected item always at the front.
@Observable
@MainActor
final class TaskSelectionStore {

  /// The task currently selected for the active Pomodoro session, or `nil` if none.
  private(set) var activeTask: TaskItem?

  /// Recent tasks keyed by provider ID, each capped at `recentsLimit` entries.
  private(set) var recentsByProvider: [String: [TaskItem]] = [:]

  private let store: SettingsStore
  static let recentsLimit = 10

  /// - Parameter store: The settings store for persistence. Override in tests.
  init(store: SettingsStore = SettingsStore()) {
    self.store = store
    load()
  }

  // MARK: - Selection

  /// Selects a task as the active task and prepends it to that provider's recents.
  ///
  /// Safe to call mid-session — does not interact with the timer state.
  /// - Parameter task: The task to make active.
  func select(_ task: TaskItem) {
    activeTask = task
    addToRecents(task)
    persist()
  }

  /// Clears the active task without affecting recents.
  func clearActiveTask() {
    activeTask = nil
    persist()
  }

  // MARK: - Recents

  /// Returns recent tasks for the given provider, newest first.
  /// - Parameter providerID: The provider whose recents to return.
  func recents(for providerID: ProviderID) -> [TaskItem] {
    recentsByProvider[providerID.rawValue] ?? []
  }

  // MARK: - Private

  private func addToRecents(_ task: TaskItem) {
    let key = task.id.providerID.rawValue
    var list = recentsByProvider[key] ?? []
    list.removeAll { $0.id == task.id }
    list.insert(task, at: 0)
    if list.count > Self.recentsLimit {
      list = Array(list.prefix(Self.recentsLimit))
    }
    recentsByProvider[key] = list
  }

  private func persist() {
    store.setValue(activeTask, forKey: SettingsStore.Keys.activeTask)
    store.setValue(recentsByProvider, forKey: SettingsStore.Keys.recentsByProvider)
  }

  private func load() {
    activeTask = store.value(forKey: SettingsStore.Keys.activeTask, as: TaskItem.self)
    recentsByProvider =
      store.value(forKey: SettingsStore.Keys.recentsByProvider, as: [String: [TaskItem]].self)
      ?? [:]
  }
}
