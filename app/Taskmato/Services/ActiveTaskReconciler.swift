//
//  ActiveTaskReconciler.swift
//  Taskmato
//

import Foundation

/// Reconciles the persisted active-task snapshot against its owning provider (issue #547).
///
/// `TaskSelectionStore.activeTask` is a `Codable` snapshot, not a live reference — nothing else
/// notices when the source provider deletes or completes the task out from under it. This type
/// closes that gap on the existing `registry.onProviderStateChanged` reload seam (the same one
/// `SelectionStore.validateSelection()` uses for the sidebar list selection): when an enabled,
/// already-loaded provider no longer contains the active task, the stale snapshot is cleared
/// through the ordinary ``TaskSelectionStore/clearActiveTask()`` path — no picker routing. If a
/// focus session is actively running, the timer is paused immediately after the stale task is
/// cleared so it does not keep counting unassigned focus time. Already-invested focus time is
/// preserved for free by the pre-existing
/// snapshot-segment attribution (`FocusAttribution`, D4 of design doc 0010), independent of the
/// snapshot itself, and untouched recents make the same task one tap away again. Only a
/// mid-focus clear surfaces a `.warning` banner — deliberately worded as "not available" rather
/// than guessing at a cause (deleted, completed elsewhere, access revoked all look the same).
@MainActor
final class ActiveTaskReconciler {

  private let registry: ProviderRegistry
  private let selectionStore: TaskSelectionStore
  private let engine: SessionEngine
  private let attribution: FocusAttribution
  private let errorPresenter: ErrorPresenter

  /// - Parameters:
  ///   - registry: Resolves the active task's owning provider and its enabled/loaded state.
  ///   - selectionStore: Holds the snapshot being reconciled.
  ///   - engine: Pauses a running focus phase after the vanished task is cleared.
  ///   - attribution: Consulted only to gate the banner on a live/paused focus phase.
  ///   - errorPresenter: Surfaces the mid-focus removal banner.
  init(
    registry: ProviderRegistry, selectionStore: TaskSelectionStore, engine: SessionEngine,
    attribution: FocusAttribution, errorPresenter: ErrorPresenter
  ) {
    self.registry = registry
    self.selectionStore = selectionStore
    self.engine = engine
    self.attribution = attribution
    self.errorPresenter = errorPresenter
  }

  /// Checks the active task against its provider, refreshing or clearing the snapshot as needed.
  ///
  /// Call after every provider list reload. A no-op unless there is an active task whose owning
  /// provider is both enabled and has already completed at least one load — that gate is what
  /// makes startup safe, since providers load asynchronously and a naive check would otherwise
  /// clear valid tasks before their provider warms up. A disabled provider is left alone: the
  /// snapshot is recoverable by re-enabling it.
  func reconcile(changedProviderID: ProviderID? = nil) async {
    guard let active = selectionStore.activeTask else { return }
    let providerID = active.id.providerID
    guard changedProviderID == nil || changedProviderID == providerID else { return }
    guard registry.isEnabled(providerID), registry.providerLists[providerID] != nil,
      let provider = registry.provider(for: active.id), provider.isAuthorized
    else { return }

    let open: [TaskItem]
    do {
      open = try await provider.tasks(in: nil)
    } catch {
      return  // A transient fetch failure is not evidence of removal — try again next reload.
    }

    if let match = provider.resolve(active.id, among: open) {
      if match != active { selectionStore.refreshActiveTask(match, replacing: active.id) }
      return
    }

    // Re-check after the await above: the task may have been re-selected, or its provider
    // disabled, while this fetch was in flight.
    guard selectionStore.activeTask?.id == active.id, registry.isEnabled(providerID) else {
      return
    }

    let wasMidFocus = attribution.isLive || engine.hasActiveFocusPhase
    let shouldPauseFocus = engine.isRunningFocus
    selectionStore.clearActiveTask()
    if shouldPauseFocus { engine.pause() }
    guard wasMidFocus else { return }  // Idle/startup removals are silent — nothing to report.
    errorPresenter.present(
      TransientError(
        title: AppLabels.Error.taskNotAvailable(title: active.title), severity: .warning))
  }
}

extension SessionEngine {
  fileprivate var hasActiveFocusPhase: Bool {
    switch state {
    case .running(.focus, _, _), .paused(.focus, _):
      return true
    case .running, .paused, .idle:
      return false
    }
  }

  fileprivate var isRunningFocus: Bool {
    if case .running(.focus, _, _) = state { return true }
    return false
  }
}
