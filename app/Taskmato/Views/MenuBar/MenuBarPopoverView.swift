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
/// browsing and swapping live in the main window (design doc 0008, D1). On first
/// appearance, binds the `openWindow` environment action onto ``MainNavigation`` and
/// reports the menu-bar scene ready to drain any buffered cold-launch URLs.
struct MenuBarPopoverView: View {

  var presenter: TimerPresenter
  var statsViewModel: StatsViewModel
  var selectionStore: TaskSelectionStore
  var nav: MainNavigation

  @Environment(\.openWindow) private var openWindow

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
        PopoverActiveTaskLine(selectionStore: selectionStore)
          .padding(.horizontal, .sectionGap)
          .padding(.vertical, .contentGap)
      } else {
        Text(AppLabels.Tooltip.selectTaskFirst)
          .font(.caption)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, .sectionGap)
          .padding(.vertical, .contentGap)
      }

      Divider()
        .padding(.horizontal, .sectionGap)

      HStack {
        Button {
          let popover = NSApp.keyWindow
          nav.showStatsInMainWindow()
          DispatchQueue.main.async { popover?.close() }
        } label: {
          Text(summaryText)
            .font(.statLabel)
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help(AppLabels.Tab.stats.title)

        Spacer()

        Button {
          let popover = NSApp.keyWindow
          nav.openMainWindow()
          DispatchQueue.main.async { popover?.close() }
        } label: {
          Text("Open \(Bundle.main.appName)")
        }
        .controlSize(.small)
      }
      .padding(.horizontal, .sectionGap)
      .padding(.vertical, .groupGap)
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

  /// A compact one-line focus summary for the bottom bar: sessions · minutes · streak.
  private var summaryText: String {
    let sessions =
      statsViewModel.todayFocusCount == 1
      ? "1 session" : "\(statsViewModel.todayFocusCount) sessions"
    var text = "\(sessions) · \(statsViewModel.todayFocusMinutes) min"
    if statsViewModel.currentStreak > 0 {
      text += " · 🔥\(statsViewModel.currentStreak)"
    }
    return text
  }
}

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
      statsViewModel: .preview)
  )
}
