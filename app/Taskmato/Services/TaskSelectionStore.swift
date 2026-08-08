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

  /// `true` after a complete/swap/clear pause routes to the task picker (D9 of design doc
  /// 0010) — a one-shot signal that the next ``select(_:)`` is a genuine handoff continuation,
  /// not an idle pick. Cleared as soon as the next selection consumes it.
  private(set) var isPendingContinuation = false

  /// Fired on every active-task change — select or clear — with the new value. Mirrors the
  /// `registry.onProviderStateChanged` idiom. `AppComposition` wires this to
  /// ``FocusAttribution/taskChanged(to:consumedSeconds:)``.
  var onActiveTaskChanged: ((TaskItem?) -> Void)?

  /// Fired when ``select(_:)`` consumes a pending continuation (D9); the caller decides whether
  /// to resume the paused phase, gated on `autoStartNextPhase`.
  var onContinuationSelect: (() -> Void)?

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
  /// Safe to call mid-session — does not interact with the timer state directly, though a
  /// pending continuation (D9) may trigger ``onContinuationSelect``.
  /// - Parameter task: The task to make active.
  func select(_ task: TaskItem) {
    activeTask = task
    addToRecents(task)
    persist()
    onActiveTaskChanged?(task)
    if isPendingContinuation {
      isPendingContinuation = false
      onContinuationSelect?()
    }
  }

  /// Clears the active task without affecting recents.
  func clearActiveTask() {
    activeTask = nil
    persist()
    onActiveTaskChanged?(nil)
  }

  /// Updates the active task's cached fields (title, notes, priority, …) from a freshly
  /// reloaded snapshot of the same reference, so external edits show up without a new selection.
  ///
  /// Unlike ``select(_:)`` this does not touch recents or the pending-continuation flag, and does
  /// not fire ``onActiveTaskChanged`` — the reference is unchanged, so no new attribution slice
  /// should open (`ActiveTaskReconciler`, issue #547). One accepted consequence: a focus segment
  /// already open against this task keeps the pre-refresh `taskTitle` when it closes, since that
  /// title was captured as a breakpoint before the rename was known.
  /// - Parameters:
  ///   - task: The reloaded task.
  ///   - replacing: The persisted reference being refreshed, which may be a legacy provider ID.
  func refreshActiveTask(_ task: TaskItem, replacing: TaskRef? = nil) {
    guard let current = activeTask, replacing == current.id || task.id == current.id else { return }
    activeTask = task
    if let replacing {
      let key = replacing.providerID.rawValue
      recentsByProvider[key]?.replaceFirst(where: { $0.id == replacing }, with: task)
    }
    persist()
  }

  /// Marks the next ``select(_:)`` as a genuine handoff continuation (D9) — call after a
  /// complete/swap/clear pauses the phase and routes to the picker.
  func markPendingContinuation() {
    isPendingContinuation = true
  }

  /// Clears a pending continuation without selecting, so a stale flag never triggers a later,
  /// unrelated selection.
  func clearPendingContinuation() {
    isPendingContinuation = false
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

extension Array {
  fileprivate mutating func replaceFirst(
    where predicate: (Element) throws -> Bool, with replacement: Element
  ) rethrows {
    guard let index = try firstIndex(where: predicate) else { return }
    self[index] = replacement
  }
}
