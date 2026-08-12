//
//  FocusAttribution.swift
//  Taskmato
//

import Foundation

/// Resolves a provider's display cosmetics for the snapshot written onto each closed slice.
/// Returns `nil` when the provider is not registered.
typealias ProviderCosmeticsResolver = (ProviderID) -> (label: String, tint: ProviderTint)?

/// Task-agnostic breakpoint log that partitions one focus phase's consumed time into per-task
/// ``FocusSegment`` values (D4 of design doc 0010).
///
/// The engine never learns about tasks — this coordinator is the sole place task identity meets
/// focus time. ``PhaseOrchestrator`` seeds it on `began(.focus)`, drains its closed-slice
/// notifications to upsert a durable draft (D7), and finalizes it on `.ended`.
///
/// Mutated from two paths — synchronously from `TaskSelectionStore.onActiveTaskChanged` (task
/// changes) and from `PhaseOrchestrator` draining the engine's event stream (phase boundaries) —
/// both on the main actor, so there is no data race. The remaining hazard is a task change
/// firing after a phase has already ended but before `PhaseOrchestrator` has drained that
/// `.ended` event and called ``finish(consumedSeconds:)``. ``taskChanged(to:consumedSeconds:)``
/// guards against this by rejecting any call whose `consumedSeconds` does not monotonically
/// advance past the last recorded breakpoint — an ended phase's live consumed time always reads
/// back as `0`, which never satisfies that guard once real progress has been recorded.
@MainActor
final class FocusAttribution {

  /// One breakpoint: the consumed-focus-seconds mark and the task active from that mark onward.
  private struct Breakpoint {
    let consumedSeconds: TimeInterval
    let task: TaskItem?
  }

  private var breakpoints: [Breakpoint] = []

  private let cosmetics: ProviderCosmeticsResolver

  /// `true` while a focus phase is seeded and not yet finished.
  private(set) var isLive = false

  /// Invoked synchronously whenever a slice closes mid-phase (a task change while live), with
  /// the newly closed segment. ``PhaseOrchestrator`` uses this to upsert the durable draft.
  var onSliceClosed: ((FocusSegment) -> Void)?

  /// - Parameter cosmetics: Resolves the provider label and tint snapshotted onto each closed
  ///   slice (ADR-0010, D4). Defaults to no snapshot, leaving both fields `nil`.
  init(cosmetics: @escaping ProviderCosmeticsResolver = { _ in nil }) {
    self.cosmetics = cosmetics
  }

  /// Seeds the log for a freshly begun focus phase with the task active at that moment.
  /// - Parameter task: The active task when the phase began, or `nil` for untracked focus.
  func begin(task: TaskItem?) {
    breakpoints = [Breakpoint(consumedSeconds: 0, task: task)]
    isLive = true
  }

  /// Records a task change mid-phase, closing the previous slice and opening the next.
  ///
  /// A no-op when no focus phase is currently live, or when `consumedSeconds` does not advance
  /// past the last breakpoint — the guard that keeps a task change racing the instant of phase
  /// completion from corrupting the next phase's log (see the type-level concurrency note).
  /// - Parameters:
  ///   - task: The newly active task, or `nil` when the selection was cleared.
  ///   - consumedSeconds: Focus seconds consumed at the moment of the change.
  func taskChanged(to task: TaskItem?, consumedSeconds: TimeInterval) {
    guard isLive, let last = breakpoints.last, consumedSeconds >= last.consumedSeconds else {
      return
    }
    breakpoints.append(Breakpoint(consumedSeconds: consumedSeconds, task: task))
    let seconds = consumedSeconds - last.consumedSeconds
    guard seconds > 0 else { return }
    onSliceClosed?(segment(for: last.task, seconds: seconds))
  }

  /// Resolves the full breakpoint log into segments and clears the log for the next phase.
  /// - Parameter consumedSeconds: Total focus seconds consumed by the phase at its end.
  /// - Returns: Non-zero-length segments, in the order the tasks held focus.
  func finish(consumedSeconds: TimeInterval) -> [FocusSegment] {
    defer {
      breakpoints = []
      isLive = false
    }
    guard !breakpoints.isEmpty else { return [] }
    var segments: [FocusSegment] = []
    for (index, breakpoint) in breakpoints.enumerated() {
      let end =
        index + 1 < breakpoints.count ? breakpoints[index + 1].consumedSeconds : consumedSeconds
      let seconds = end - breakpoint.consumedSeconds
      guard seconds > 0 else { continue }
      segments.append(segment(for: breakpoint.task, seconds: seconds))
    }
    return segments
  }

  /// Builds a slice, snapshotting the owning provider's cosmetics when it resolves.
  private func segment(for task: TaskItem?, seconds: TimeInterval) -> FocusSegment {
    let snapshot = task.flatMap { cosmetics($0.id.providerID) }
    return FocusSegment(
      id: UUID(), taskRef: task?.id, taskTitle: task?.title, seconds: seconds,
      providerLabel: snapshot?.label, providerTint: snapshot?.tint)
  }
}
