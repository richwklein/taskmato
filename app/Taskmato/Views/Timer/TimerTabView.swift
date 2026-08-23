//
//  TimerTabView.swift
//  Taskmato
//

import SwiftUI

/// The timer tab shown in the main application window.
struct TimerTabView: View {

  var presenter: TimerPresenter
  var nextUpPresenter: NextUpPresenter
  var engine: SessionEngine
  var statsViewModel: StatsViewModel
  var activeTaskStore: ActiveTaskStore
  var registry: ProviderRegistry
  var nav: MainNavigation
  var errorPresenter: ErrorPresenter

  var body: some View {
    VStack(spacing: 0) {
      Spacer()

      CircularTimerView(presenter: presenter, nextUpPresenter: nextUpPresenter)

      TimerControlsView(
        presenter: presenter,
        size: .regular,
        startDisabled: activeTaskStore.activeTask == nil,
        startDisabledHelp: AppLabels.Tooltip.selectTaskFirst
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
    let timerPresenter = TimerPresenter(engine: engine, settings: settings)
    return TimerTabView(
      presenter: timerPresenter,
      nextUpPresenter: NextUpPresenter(
        presenter: timerPresenter, activeTaskStore: activeTaskStore, settings: settings),
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
