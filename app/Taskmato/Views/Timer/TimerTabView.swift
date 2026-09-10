//
//  TimerTabView.swift
//  Taskmato
//

import SwiftUI

/// The timer tab shown in the main application window.
///
/// Contributes the window's only toolbar search field (``TimerSearchPresenter``): typing shows
/// title-matching tasks in a floating panel over the ring, and picking one tracks it in place —
/// no navigation, no pause. See the PR body for why this departs from design doc 0010's
/// mid-focus task-change handling.
struct TimerTabView: View {

  var presenter: TimerPresenter
  var nextUpPresenter: NextUpPresenter
  var searchPresenter: TimerSearchPresenter
  var engine: SessionEngine
  var statsViewModel: StatsViewModel
  var activeTaskStore: ActiveTaskStore
  var registry: ProviderRegistry
  var nav: MainNavigation
  var errorPresenter: ErrorPresenter

  @FocusState private var isSearchFocused: Bool

  /// Routes the search field's text through the presenter's debounce rather than holding it as
  /// separate view state.
  private var searchBinding: Binding<String> {
    Binding(
      get: { searchPresenter.query },
      set: { searchPresenter.queryChanged($0) }
    )
  }

  var body: some View {
    content
      .searchable(
        text: searchBinding, placement: .toolbar, prompt: AppLabels.Search.findTaskPrompt
      )
      .searchFocused($isSearchFocused)
      .focusedSceneValue(\.focusSearch, { isSearchFocused = true })
      .onSubmit(of: .search) {
        searchPresenter.trackHighlighted()
        isSearchFocused = false
      }
      // Whether these land while focus sits in the toolbar's `NSSearchField` is unverified —
      // the field may consume arrows first. `.ignored` with no results leaves the keys to
      // whatever else wants them, and Return plus a row click work regardless.
      .onKeyPress(.upArrow) { moveHighlight(by: -1) }
      .onKeyPress(.downArrow) { moveHighlight(by: 1) }
      // Hangs off the toolbar field's trailing edge like a native completion list, rather than
      // floating centered over the ring. The trailing inset matches the field's own inset from
      // the window edge; the top gap separates the panel from the toolbar's divider.
      .overlay(alignment: .topTrailing) {
        if !searchPresenter.query.isEmpty {
          TimerSearchResultsPanel(presenter: searchPresenter) { task in
            searchPresenter.track(task)
            isSearchFocused = false
          }
          .padding(.top, .contentGap)
          .padding(.trailing, .groupGap)
        }
      }
      // The load-bearing half of the panel's VoiceOver parity: while typing, focus stays in the
      // toolbar's `NSSearchField`, so a static label alone gives no signal that results landed.
      // Gated to the searching→settled transition only — never on entry, a dropped stale
      // response, or the query going empty (Esc, cancel, or the clear() after a pick).
      .onChange(of: searchPresenter.isSearching) { was, now in
        guard was, !now, !searchPresenter.query.isEmpty else { return }
        AccessibilityNotification.Announcement(
          AppLabels.Search.resultCount(searchPresenter.results.count)
        ).post()
      }
      // MainWindowView.detail switches on nav.destination, so leaving Timer removes this view
      // from the hierarchy while the composition-owned presenter survives. Without this, ⌘1 back
      // repopulates the toolbar field and the panel from a snapshot fetched before the excursion.
      .onDisappear { searchPresenter.clear() }
  }

  /// Moves the panel's highlight, claiming the key only while there are results to move through.
  /// - Parameter delta: `+1` for the next row, `-1` for the previous.
  private func moveHighlight(by delta: Int) -> KeyPress.Result {
    guard !searchPresenter.results.isEmpty else { return .ignored }
    searchPresenter.moveHighlight(by: delta)
    return .handled
  }

  private var content: some View {
    VStack(spacing: 0) {
      Spacer()

      CircularTimerView(presenter: presenter, nextUpPresenter: nextUpPresenter)

      TimerControlsView(
        presenter: presenter,
        size: .regular,
        primaryDisabledHelp: AppLabels.Tooltip.selectTaskFirst
      )
      .padding(.top, 20)
      .padding(.bottom, .screenPadding)

      Spacer()

      Divider()
        .padding(.horizontal, .screenPadding)

      if activeTaskStore.activeTask != nil || nextUpPresenter.showsNextUp {
        ActiveTaskView(
          engine: engine, activeTaskStore: activeTaskStore, registry: registry, nav: nav,
          errorPresenter: errorPresenter, style: .detail, nextUp: nextUpPresenter, onSelect: nil
        )
        .padding(.horizontal, .sectionGap)
        .padding(.vertical, .contentGap)
      } else {
        BrowseTasksButton { nav.showTasks() }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, .sectionGap)
          .padding(.vertical, .contentGap)
      }

      Divider()
        .padding(.horizontal, .screenPadding)

      SessionStatsView(
        count: statsViewModel.todayFocusCount, seconds: statsViewModel.todayFocusSeconds,
        streak: statsViewModel.currentStreak, layout: .spread,
        onSelect: { nav.showStats() }
      )
      .padding(.horizontal, .screenPadding)
      .padding(.vertical, .groupGap)
    }
  }
}

#if DEBUG
  #Preview {
    let engine = SessionEngine()
    let settings = AppSettings()
    let registry = ProviderRegistry()
    let activeTaskStore = ActiveTaskStore()
    let timerPresenter = TimerPresenter(
      engine: engine, settings: settings, activeTaskStore: activeTaskStore)
    let queryService = TaskQueryService(registry: registry, sorter: TaskSorter())
    return TimerTabView(
      presenter: timerPresenter,
      nextUpPresenter: NextUpPresenter(
        presenter: timerPresenter, activeTaskStore: activeTaskStore, settings: settings),
      searchPresenter: TimerSearchPresenter(
        queryService: queryService, settings: settings, activeTaskStore: activeTaskStore,
        registry: registry),
      engine: engine,
      statsViewModel: .preview,
      activeTaskStore: activeTaskStore,
      registry: registry,
      nav: MainNavigation(
        settings: settings, selectionStore: SelectionStore(registry: registry),
        statsViewModel: .preview),
      errorPresenter: ErrorPresenter()
    )
  }
#endif
