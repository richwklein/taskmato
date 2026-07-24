//
//  MenuBarPopoverView.swift
//  Taskmato
//
//  Created by Richard Klein on 5/2/26.
//

import SwiftUI

/// The compact popover view shown when the user clicks the menu bar item.
///
/// Provides quick timer controls and a button to open the main application window.
/// On first appearance, binds the `openWindow` environment action onto ``MainNavigation``
/// and reports the menu-bar scene ready to drain any buffered cold-launch URLs.
struct MenuBarPopoverView: View {

  var presenter: TimerPresenter
  var engine: SessionEngine
  var statsViewModel: StatsViewModel
  var selectionStore: TaskSelectionStore
  var registry: ProviderRegistry
  var nav: MainNavigation

  @Environment(\.openSettings) private var openSettings
  @Environment(\.openWindow) private var openWindow

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Button {
          let popover = NSApp.keyWindow
          NSApp.activate(ignoringOtherApps: true)
          openSettings()
          DispatchQueue.main.async { popover?.close() }
        } label: {
          Image(systemName: "gearshape")
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)

        Spacer()

        Button {
          let popover = NSApp.keyWindow
          nav.openMainWindow()
          DispatchQueue.main.async { popover?.close() }
        } label: {
          Image(systemName: "arrow.up.forward.app")
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help("Open \(Bundle.main.appName)")
      }
      .padding(.horizontal, .sectionGap)
      .padding(.top, .groupGap)
      .padding(.bottom, .contentGap)

      CircularTimerView(
        progress: presenter.progress,
        label: presenter.label,
        phase: presenter.phaseName
      )

      TimerControlsView(
        presenter: presenter,
        startDisabled: selectionStore.activeTask == nil,
        startDisabledHelp: AppLabels.Tooltip.selectTaskFirst
      )
      .frame(height: 44)
      .padding(.top, .sectionGap)
      .padding(.bottom, .groupGap)

      Divider()
        .padding(.horizontal, .sectionGap)

      if selectionStore.activeTask != nil {
        ActiveTaskView(engine: engine, selectionStore: selectionStore, registry: registry, nav: nav)
      } else {
        Button {
          let popover = NSApp.keyWindow
          nav.openMainWindow()
          nav.showTasks()
          DispatchQueue.main.async { popover?.close() }
        } label: {
          Label(AppLabels.View.browseTask.title, systemImage: AppLabels.View.browseTask.systemImage)
            .font(.caption)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .padding(.horizontal, .sectionGap)
        .padding(.vertical, .iconLabel)
      }

      Divider()
        .padding(.horizontal, .sectionGap)

      Button {
        let popover = NSApp.keyWindow
        nav.showStatsInMainWindow()
        DispatchQueue.main.async { popover?.close() }
      } label: {
        SessionStatsView(
          count: statsViewModel.todayFocusCount, minutes: statsViewModel.todayFocusMinutes,
          streak: statsViewModel.currentStreak)
      }
      .buttonStyle(.plain)
      .padding(.horizontal, .sectionGap)
      .padding(.vertical, .cardPadding)
    }
    .frame(width: 280)
    .onAppear {
      nav.bindOpenMainWindow {
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: "main")
      }
      (NSApp.delegate as? AppDelegate)?.reportScenesReady()
    }
  }
}

#Preview {
  let engine = SessionEngine()
  let settings = AppSettings()
  let registry = ProviderRegistry()
  return MenuBarPopoverView(
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
