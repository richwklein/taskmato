//
//  TimerTabView.swift
//  Taskmato
//

import SwiftUI

/// The timer tab shown in the main application window.
struct TimerTabView: View {

  var presenter: TimerPresenter
  var engine: SessionEngine
  var statsViewModel: StatsViewModel
  var selectionStore: TaskSelectionStore
  var registry: ProviderRegistry
  var nav: MainNavigation
  var errorPresenter: ErrorPresenter

  var body: some View {
    VStack(spacing: 0) {
      Spacer()

      CircularTimerView(
        progress: presenter.progress,
        label: presenter.label,
        phase: presenter.phaseName,
        accessibilityValue: presenter.accessibilityValue
      )

      TimerControlsView(
        presenter: presenter,
        size: .regular,
        startDisabled: selectionStore.activeTask == nil,
        startDisabledHelp: AppLabels.Tooltip.selectTaskFirst
      )
      .padding(.top, 20)
      .padding(.bottom, .screenPadding)

      Spacer()

      Divider()
        .padding(.horizontal, .screenPadding)

      if selectionStore.activeTask != nil {
        ActiveTaskView(
          engine: engine, selectionStore: selectionStore, registry: registry, nav: nav,
          errorPresenter: errorPresenter, style: .detail, onSelect: nil
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
        count: statsViewModel.todayFocusCount, minutes: statsViewModel.todayFocusMinutes,
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
    return TimerTabView(
      presenter: TimerPresenter(engine: engine, settings: settings),
      engine: engine,
      statsViewModel: .preview,
      selectionStore: TaskSelectionStore(),
      registry: registry,
      nav: MainNavigation(
        settings: settings, selectionStore: SelectionStore(registry: registry),
        statsViewModel: .preview),
      errorPresenter: ErrorPresenter()
    )
  }
#endif
