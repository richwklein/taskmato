//
//  MenuBarPopoverView.swift
//  Taskmato
//
//  Created by Richard Klein on 5/2/26.
//

import SwiftUI

/// The slim companion popover shown when the user clicks the menu bar item.
///
/// Glanceable timer state and controls only — countdown, phase, start/pause/skip/stop, a
/// display-only active-task line, today's session summary, and "Open Taskmato". Task
/// browsing and swapping live in the main window (design doc 0008, D1). Opening the window
/// goes through ``MainNavigation``, whose reopen action is bound by the main window itself.
struct MenuBarPopoverView: View {

  var presenter: TimerPresenter
  var statsViewModel: StatsViewModel
  var selectionStore: TaskSelectionStore
  var nav: MainNavigation
  var engine: SessionEngine
  var registry: ProviderRegistry
  var errorPresenter: ErrorPresenter

  var body: some View {
    VStack(spacing: 0) {
      TimerReadout(label: presenter.label, phase: presenter.phaseName)
        .padding(.top, .groupGap)

      TimerControlsView(
        presenter: presenter,
        size: .compact,
        startDisabled: selectionStore.activeTask == nil,
        startDisabledHelp: AppLabels.Tooltip.selectTaskFirst
      )
      .padding(.top, .sectionGap)
      .padding(.bottom, .groupGap)

      Divider()
        .padding(.horizontal, .sectionGap)

      if selectionStore.activeTask != nil {
        ActiveTaskView(
          engine: engine, selectionStore: selectionStore, registry: registry, nav: nav,
          errorPresenter: errorPresenter, style: .compact,
          onSelect: { dismissPopover { nav.showTimerInMainWindow() } }
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, .sectionGap)
        .padding(.vertical, .contentGap)
      } else {
        BrowseTasksButton { dismissPopover { nav.showTasksInMainWindow() } }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, .sectionGap)
          .padding(.vertical, .contentGap)
      }

      Divider()
        .padding(.horizontal, .sectionGap)

      HStack {
        SessionStatsView(
          count: statsViewModel.todayFocusCount, minutes: statsViewModel.todayFocusMinutes,
          streak: statsViewModel.currentStreak, layout: .inline,
          onSelect: { dismissPopover { nav.showStatsInMainWindow() } }
        )

        Spacer()

        Button {
          dismissPopover { nav.openMainWindow() }
        } label: {
          Text("Open \(Bundle.main.appName)")
        }
        .controlSize(.small)
      }
      .padding(.horizontal, .sectionGap)
      .padding(.vertical, .groupGap)
    }
    .frame(width: 280)
  }

  /// Routes through `MainNavigation`, then closes the popover on the next runloop turn so the
  /// window activation is not cancelled by the popover tearing down first.
  private func dismissPopover(then route: @escaping () -> Void) {
    let popover = NSApp.keyWindow
    route()
    DispatchQueue.main.async { popover?.close() }
  }
}

#if DEBUG
  #Preview {
    let engine = SessionEngine()
    let settings = AppSettings()
    let registry = ProviderRegistry()
    return MenuBarPopoverView(
      presenter: TimerPresenter(engine: engine, settings: settings),
      statsViewModel: .preview,
      selectionStore: TaskSelectionStore(),
      nav: MainNavigation(
        settings: settings, selectionStore: SelectionStore(registry: registry),
        statsViewModel: .preview),
      engine: engine,
      registry: registry,
      errorPresenter: ErrorPresenter()
    )
  }
#endif
