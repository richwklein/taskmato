//
//  ActiveTaskReconciler.swift
//  Taskmato
//

import Foundation

/// Reconciles the persisted active-task and staged-task snapshots against their owning providers
/// (issue #547, design doc "stage the next focus").
///
/// `TaskSelectionStore.activeTask` and `stagedTask` are `Codable` snapshots, not live references —
/// nothing else notices when the source provider deletes or completes one of those tasks out from
/// under it. This type closes that gap on the existing `registry.onProviderStateChanged` reload
/// seam (the same one `SelectionStore.validateSelection()` uses for the sidebar list selection):
/// when an enabled, already-loaded provider no longer contains a tracked task, the stale snapshot
/// is cleared. For the active task that is the ordinary ``TaskSelectionStore/clearActiveTask()``
/// path — no picker routing. If a focus session is actively running, the timer is paused
/// immediately after the stale task is cleared so it does not keep counting unassigned focus time.
/// Already-invested focus time is preserved for free by the pre-existing snapshot-segment
/// attribution (`FocusAttribution`, D4 of design doc 0010), independent of the snapshot itself,
/// and untouched recents make the same task one tap away again. Only a mid-focus clear surfaces a
/// `.warning` banner — deliberately worded as "not available" rather than guessing at a cause
/// (deleted, completed elsewhere, access revoked all look the same). The staged task is reconciled
/// on its own, independently gated leg (D-c/D-e of "stage the next focus"): it carries no focus
/// time, so a vanished staged task simply clears — silently, no banner, no pause.
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

  /// Checks the active and staged tasks against their owning providers, refreshing or clearing
  /// each snapshot as needed.
  ///
  /// Call after every provider list reload. Runs two independently gated legs —
  /// ``reconcileStaged(changedProviderID:)`` then ``reconcileActive(changedProviderID:)`` — each a
  /// no-op unless it has a snapshot whose owning provider is both enabled and has already
  /// completed at least one load. That gate is what makes startup safe, since providers load
  /// asynchronously and a naive check would otherwise clear valid tasks before their provider
  /// warms up. A disabled provider is left alone: the snapshot is recoverable by re-enabling it.
  func reconcile(changedProviderID: ProviderID? = nil) async {
    await reconcileStaged(changedProviderID: changedProviderID)
    await reconcileActive(changedProviderID: changedProviderID)
  }

  /// Checks ``TaskSelectionStore/stagedTask`` against its owning provider.
  ///
  /// Gated on the *staged* task's own provider — deliberately separate from
  /// ``reconcileActive(changedProviderID:)``'s gate, since a staged task can sit in a different
  /// provider than the active task, or exist with no active task at all. A vanished staged task
  /// carries no focus time, so it clears silently: no banner, no ``SessionEngine/pause()``. If the
  /// staged slot is empty by the time the fetch returns *and* the active task is now the formerly
  /// staged task, the synchronous promotion at `PhaseOrchestrator.began(.focus)` won this race —
  /// the verdict is about the active task now, so this falls through to the active-vanished path
  /// instead of waiting for a later reload.
  private func reconcileStaged(changedProviderID: ProviderID?) async {
    guard let staged = selectionStore.stagedTask else { return }
    guard let provider = eligibleProvider(for: staged.id, changedProviderID: changedProviderID)
    else { return }

    let open: [TaskItem]
    do {
      open = try await provider.tasks(in: nil)
    } catch {
      return  // A transient fetch failure is not evidence of removal — try again next reload.
    }

    if let match = provider.resolve(staged.id, among: open) {
      if match != staged { selectionStore.refreshStagedTask(match) }
      return
    }

    // Re-check after the await above: staging or promotion may have landed while this fetch was
    // in flight.
    if selectionStore.stagedTask?.id == staged.id {
      selectionStore.clearStagedTask()
      return
    }
    guard selectionStore.activeTask?.id == staged.id,
      registry.isEnabled(staged.id.providerID)
    else { return }
    clearVanishedActiveTask(staged)
  }

  /// Checks ``TaskSelectionStore/activeTask`` against its owning provider, refreshing or clearing
  /// the snapshot as needed.
  private func reconcileActive(changedProviderID: ProviderID?) async {
    guard let active = selectionStore.activeTask else { return }
    guard let provider = eligibleProvider(for: active.id, changedProviderID: changedProviderID)
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
    guard selectionStore.activeTask?.id == active.id, registry.isEnabled(active.id.providerID)
    else { return }

    clearVanishedActiveTask(active)
  }

  /// Resolves the enabled, already-loaded, authorized provider for `id`, or `nil` if the
  /// change-notification gate or the readiness gate rejects it. Shared verdict logic between the
  /// two reconciliation legs; each leg still performs its own `tasks(in:)` fetch.
  private func eligibleProvider(for id: TaskRef, changedProviderID: ProviderID?) -> TaskProvider? {
    let providerID = id.providerID
    guard changedProviderID == nil || changedProviderID == providerID else { return nil }
    guard registry.isEnabled(providerID), registry.providerLists[providerID] != nil,
      let provider = registry.provider(for: id), provider.isAuthorized
    else { return nil }
    return provider
  }

  /// Clears a vanished active task, pausing a running focus phase and surfacing a `.warning`
  /// banner if the removal happened mid-focus. Shared by ``reconcileActive(changedProviderID:)``
  /// and case 2 of ``reconcileStaged(changedProviderID:)``, where a synchronous promotion turned a
  /// vanished staged task into a vanished active one.
  /// - Parameter task: The snapshot that no longer resolves, used only for the banner's title.
  private func clearVanishedActiveTask(_ task: TaskItem) {
    let wasMidFocus = attribution.isLive || engine.hasActiveFocusPhase
    let shouldPauseFocus = engine.isRunningFocus
    selectionStore.clearActiveTask()
    if shouldPauseFocus { engine.pause() }
    guard wasMidFocus else { return }  // Idle/startup removals are silent — nothing to report.
    errorPresenter.present(
      TransientError(
        title: AppLabels.Error.taskNotAvailable(title: task.title), severity: .warning))
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
