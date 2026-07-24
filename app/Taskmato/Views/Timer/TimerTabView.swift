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

  var body: some View {
    VStack(spacing: 0) {
      Spacer()

      CircularTimerView(
        progress: presenter.progress,
        label: presenter.label,
        phase: presenter.phaseName
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
          showNotes: true
        )
        .padding(.horizontal, .contentGap)
      } else {
        Button {
          nav.showTasks()
        } label: {
          Label(AppLabels.View.browseTask.title, systemImage: AppLabels.View.browseTask.systemImage)
            .font(.caption)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .padding(.horizontal, .screenPadding)
        .padding(.vertical, .iconLabel)
      }

      Divider()
        .padding(.horizontal, .screenPadding)

      SessionStatsView(
        count: statsViewModel.todayFocusCount, minutes: statsViewModel.todayFocusMinutes,
        streak: statsViewModel.currentStreak
      )
      .padding(.horizontal, .screenPadding)
      .padding(.vertical, .groupGap)
    }
  }
}

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
      statsViewModel: .preview)
  )
}
