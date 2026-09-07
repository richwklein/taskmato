//
//  TimerSearchPresenter.swift
//  Taskmato
//

import Foundation
import Observation

/// Drives the Timer tab's toolbar search field and its floating results panel.
///
/// Fetches title-matching tasks cross-provider on a debounced timer and tracks the picked task
/// directly — the mid-focus pause/continuation dance `ActiveTaskView.swapTapped()` uses does not
/// apply here, since a search pick has no browsing gap to protect the outgoing slice from (see
/// the PR body). Constructed once in `AppComposition` and handed only to `TimerTabView`.
@Observable
@MainActor
final class TimerSearchPresenter {

  private let queryService: TaskQueryService
  private let settings: AppSettings
  private let activeTaskStore: ActiveTaskStore
  private let registry: ProviderRegistry
  private let debouncer = Debouncer()

  /// The text bound to the toolbar search field.
  var query: String = ""

  /// The current title-matching result set. Not truncated — the panel caps its own height and
  /// scrolls instead (see `TimerSearchResultsPanel`).
  var results: [TaskItem] = []

  /// `true` while a fetch for the current query is in flight. Drives the panel's
  /// searching/results/empty precedence, not merely a spinner.
  var isSearching = false

  /// The row `.onSubmit(of: .search)` and the panel's row hover act on. Reset to `0` on every
  /// fresh, non-stale result set — there is no "nothing highlighted" state beyond
  /// `results.isEmpty`.
  var highlightedIndex = 0

  /// - Parameters:
  ///   - queryService: Fans out the cross-provider title search.
  ///   - settings: Supplies the task sort field and direction the results honor.
  ///   - activeTaskStore: Tracks the picked task.
  ///   - registry: Resolves provider icons for row lineage.
  init(
    queryService: TaskQueryService, settings: AppSettings, activeTaskStore: ActiveTaskStore,
    registry: ProviderRegistry
  ) {
    self.queryService = queryService
    self.settings = settings
    self.activeTaskStore = activeTaskStore
    self.registry = registry
  }

  /// Applies a new field value: trims to decide emptiness, then either clears the results or
  /// schedules a debounced fetch. Called from the search field's `Binding` setter so the
  /// debounce stays inside this presenter rather than the view.
  /// - Parameter newValue: The field's raw text.
  func queryChanged(_ newValue: String) {
    query = newValue
    guard !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      debouncer.cancel()
      results = []
      highlightedIndex = 0
      isSearching = false
      return
    }
    debouncer.schedule { [weak self] in await self?.fetch() }
  }

  /// Moves the highlight by `delta`, clamped to the result set's bounds. A no-op on an empty set.
  /// - Parameter delta: `+1` for the next row, `-1` for the previous.
  func moveHighlight(by delta: Int) {
    guard !results.isEmpty else { return }
    highlightedIndex = min(max(highlightedIndex + delta, 0), results.count - 1)
  }

  /// Tracks the highlighted row, or does nothing on an empty result set — the `Return`-picks
  /// fallback for when arrow-key highlighting is unreachable from the toolbar field.
  func trackHighlighted() {
    guard results.indices.contains(highlightedIndex) else { return }
    track(results[highlightedIndex])
  }

  /// Makes `task` the active task and resets the search — the pick gesture for both a row click
  /// and ``trackHighlighted()``. Never pauses the engine.
  /// - Parameter task: The task to track.
  func track(_ task: TaskItem) {
    activeTaskStore.track(task)
    clear()
  }

  /// Resets the field, results, highlight, and searching flag, and cancels any pending fetch.
  /// Called after a pick and from `TimerTabView`'s `.onDisappear`. A stale in-flight response is
  /// left to the fetch's own guard, which fails once `query` no longer matches.
  func clear() {
    query = ""
    results = []
    highlightedIndex = 0
    isSearching = false
    debouncer.cancel()
  }

  /// Builds a ``TaskLineage`` for a result row — the cross-provider counterpart to
  /// `TaskDetailView.lineage(for:)`, minus its single-provider-scope guard, since every result
  /// here is already cross-provider.
  /// - Parameter task: The task to describe.
  func lineage(for task: TaskItem) -> TaskLineage? {
    let showIcon = registry.enabledIDs.count > 1
    let provider = registry.providers.first { $0.id == task.id.providerID }
    let lineage = TaskLineage(
      providerIcon: showIcon ? provider?.icon : nil,
      listName: task.list?.name,
      sectionName: task.section
    )
    return lineage.isEmpty ? nil : lineage
  }

  /// Runs the debounced fetch: sets `isSearching`, fans out the title search, then applies the
  /// response only if `query` has not moved on. A dropped stale response leaves `isSearching`
  /// `true`, since the live fetch for the current query is still running.
  private func fetch() async {
    isSearching = true
    let searchedQuery = query
    let (tasks, _) = await queryService.tasks(
      query: .crossProvider(filter: .titleContains(searchedQuery)),
      sortBy: settings.taskSortField, direction: settings.taskSortDirection)
    guard searchedQuery == query else { return }
    results = tasks
    highlightedIndex = 0
    isSearching = false
  }
}
