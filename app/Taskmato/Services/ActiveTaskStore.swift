//
//  ActiveTaskStore.swift
//  Taskmato
//

import Foundation
import Observation

/// Owns the currently tracked task, a per-provider recents list, and a task staged for the
/// next focus phase.
///
/// "Tracked" is the task focus time is credited to — distinct from the task list's highlighted
/// row (`TaskDetailView.selectedTaskID`), which is ephemeral and credits nothing, and from the
/// sidebar's scope (``SelectionStore``).
///
/// The tracked task and recents are persisted to `UserDefaults` so they survive app relaunch.
/// Recents are capped at 10 entries per provider, with the most recently tracked item always at
/// the front. The staged task (design doc "stage the next focus") is not persisted — it is a
/// within-run intent only.
@Observable
@MainActor
final class ActiveTaskStore {

  /// The task currently tracked for the active Pomodoro session, or `nil` if none.
  private(set) var activeTask: TaskItem?

  /// The task queued to become active at the next focus phase's start, or `nil` if none — the
  /// "Focus Next" gesture's promise (design doc "stage the next focus", D-a). Not persisted:
  /// staging is a within-run intent, and surviving days to ambush a future session would be
  /// worse than losing it on quit (D-c).
  private(set) var stagedTask: TaskItem?

  /// Recent tasks keyed by provider ID, each capped at `recentsLimit` entries.
  private(set) var recentsByProvider: [String: [TaskItem]] = [:]

  /// `true` after a complete/swap/clear pause routes to the task picker (D9 of design doc
  /// 0010) — a one-shot signal that the next ``track(_:)`` is a genuine handoff continuation,
  /// not an idle pick. Cleared as soon as the next tracked task consumes it.
  private(set) var isPendingContinuation = false

  /// Fired on every active-task change — select or clear — with the new value. Mirrors the
  /// `registry.onProviderStateChanged` idiom. `AppComposition` wires this to
  /// ``FocusAttribution/taskChanged(to:consumedSeconds:)``.
  var onActiveTaskChanged: ((TaskItem?) -> Void)?

  /// Fired when ``track(_:)`` consumes a pending continuation (D9); the caller decides whether
  /// to resume the paused phase, gated on `autoStartNextPhase`.
  var onContinuationSelect: (() -> Void)?

  /// Fired when ``promoteStaged()`` promotes ``stagedTask`` — the complete gesture's handoff
  /// (design doc "stage the next focus", D-f), never the phase-boundary handoff. The caller
  /// decides whether to resume the paused phase, gated on `autoStartNextPhase`.
  var onStagedPromotion: (() -> Void)?

  private let store: SettingsStore
  static let recentsLimit = 10

  /// - Parameter store: The settings store for persistence. Override in tests.
  init(store: SettingsStore = SettingsStore()) {
    self.store = store
    load()
  }

  // MARK: - Tracking

  /// Makes `task` the tracked task and prepends it to that provider's recents.
  ///
  /// Safe to call mid-session — does not interact with the timer state directly, though a
  /// pending continuation (D9) may trigger ``onContinuationSelect``. Tracking explicitly wins
  /// over a staged task, so ``stagedTask`` is cleared too (design doc "stage the next focus", D-e).
  /// - Parameter task: The task to track.
  func track(_ task: TaskItem) {
    stagedTask = nil
    activeTask = task
    addToRecents(task)
    persist()
    onActiveTaskChanged?(task)
    if isPendingContinuation {
      isPendingContinuation = false
      onContinuationSelect?()
    }
  }

  /// Clears the active task without affecting recents. Also drops a staged task (design doc
  /// "stage the next focus", D-e) — an explicit clear wins.
  func clearActiveTask() {
    stagedTask = nil
    activeTask = nil
    persist()
    onActiveTaskChanged?(nil)
  }

  // MARK: - Staging (design doc "stage the next focus")

  /// Queues `task` to become active at the next focus phase's start, without disturbing the
  /// task running now (D-a).
  /// - Parameter task: The task to stage.
  func stage(_ task: TaskItem) {
    stagedTask = task
  }

  /// Drops the staged task without touching the active task. The staged length
  /// (`settings.focusMinutes`) is left alone — under D-b it is a persisted default, not a
  /// per-plan promise, so it legitimately survives (D-e).
  func clearStagedTask() {
    stagedTask = nil
  }

  /// Promotes ``stagedTask`` to ``activeTask`` at a focus phase's start, firing no resume
  /// callback. Called from `PhaseOrchestrator.began(.focus)`, which `skip()` can reach from a
  /// *paused* state — skip-from-paused must stay paused, so this never resumes anything. A
  /// no-op when nothing is staged.
  func applyStagedTask() {
    guard let staged = stagedTask else { return }
    stagedTask = nil
    promote(staged)
  }

  /// Promotes ``stagedTask`` to ``activeTask`` and fires ``onStagedPromotion`` — the complete
  /// gesture's handoff (D-f): with a task staged there is nothing left to pick, so completing
  /// hands off directly instead of routing to the picker. A no-op when nothing is staged.
  func promoteStaged() {
    guard let staged = stagedTask else { return }
    stagedTask = nil
    promote(staged)
    onStagedPromotion?()
  }

  /// Updates the staged task's cached fields from a freshly reloaded snapshot of the same
  /// reference, mirroring ``refreshActiveTask(_:replacing:)`` for the staged slot — used by the
  /// reconciler so external edits show up without disturbing the staged plan.
  /// - Parameter task: The reloaded task.
  func refreshStagedTask(_ task: TaskItem) {
    guard let staged = stagedTask, task.id == staged.id else { return }
    stagedTask = task
  }

  /// Updates the active task's cached fields (title, notes, priority, …) from a freshly
  /// reloaded snapshot of the same reference, so external edits show up without re-tracking.
  ///
  /// Unlike ``track(_:)`` this does not touch recents or the pending-continuation flag, and does
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

  /// Marks the next ``track(_:)`` as a genuine handoff continuation (D9) — call after a
  /// complete/swap/clear pauses the phase and routes to the picker.
  func markPendingContinuation() {
    isPendingContinuation = true
  }

  /// Clears a pending continuation without tracking, so a stale flag never triggers a later,
  /// unrelated handoff.
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

  /// Applies `task` as the active task: sets ``activeTask``, adds it to recents, persists, and
  /// fires ``onActiveTaskChanged``. The one core both ``applyStagedTask()`` and
  /// ``promoteStaged()`` share; never touches ``isPendingContinuation`` — promotion is a
  /// distinct handoff, not a continuation-select (design doc "stage the next focus", D-f).
  private func promote(_ task: TaskItem) {
    activeTask = task
    addToRecents(task)
    persist()
    onActiveTaskChanged?(task)
  }

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
