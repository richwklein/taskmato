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

  private let defaults: UserDefaults
  private static let activeTaskKey = "taskSelection.activeTask"
  private static let recentsKey = "taskSelection.recentsByProvider"
  static let recentsLimit = 10

  /// - Parameter defaults: `UserDefaults` store for persistence. Override in tests.
  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
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
  func recents(for providerID: String) -> [TaskItem] {
    recentsByProvider[providerID] ?? []
  }

  // MARK: - Private

  private func addToRecents(_ task: TaskItem) {
    var list = recentsByProvider[task.id.providerID] ?? []
    list.removeAll { $0.id == task.id }
    list.insert(task, at: 0)
    if list.count > Self.recentsLimit {
      list = Array(list.prefix(Self.recentsLimit))
    }
    recentsByProvider[task.id.providerID] = list
  }

  private func persist() {
    let encoder = JSONEncoder()
    if let activeTask, let data = try? encoder.encode(activeTask) {
      defaults.set(data, forKey: Self.activeTaskKey)
    } else {
      defaults.removeObject(forKey: Self.activeTaskKey)
    }
    if let data = try? encoder.encode(recentsByProvider) {
      defaults.set(data, forKey: Self.recentsKey)
    }
  }

  private func load() {
    let decoder = JSONDecoder()
    if let data = defaults.data(forKey: Self.activeTaskKey) {
      activeTask = try? decoder.decode(TaskItem.self, from: data)
    }
    if let data = defaults.data(forKey: Self.recentsKey) {
      recentsByProvider = (try? decoder.decode([String: [TaskItem]].self, from: data)) ?? [:]
    }
  }
}
