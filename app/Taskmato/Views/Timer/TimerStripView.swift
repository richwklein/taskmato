//
//  TimerStripView.swift
//  Taskmato
//

import SwiftUI

/// A compact session bar pinned below the detail column while a session is non-idle.
///
/// Keeps the countdown and core controls visible from any non-Timer destination: a mini
/// progress ring, the active task, the phase and countdown, and the shared pause/resume ·
/// skip · stop controls. When a task is active, the phase + countdown sits inline just after
/// the task title on a single line (`.secondary`); with no active task it stands alone as a
/// `.primary` line. Clicking the ring, the countdown, or the task title jumps to the Timer
/// destination; the active task's radio stays a sibling control so completing or clearing
/// mid-session never navigates. The window gates visibility via ``SessionIndicators``; this
/// view assumes it is only shown when non-idle, so its controls never surface Start.
struct TimerStripView: View {

  /// The presenter supplying timer display values and receiving control intents.
  let presenter: TimerPresenter
  /// The session engine backing the active-task radio's complete/clear actions.
  var engine: SessionEngine
  /// The store naming the active task shown beneath the countdown.
  var selectionStore: TaskSelectionStore
  /// The registry used to resolve the active task's completion affordance.
  var registry: ProviderRegistry
  /// The navigation model the active task's title and swap action route through.
  var nav: MainNavigation
  /// Surfaces errors from the active task's completion action.
  var errorPresenter: ErrorPresenter
  /// Invoked when the user clicks the ring, countdown, or active-task title.
  var onSelectTimer: () -> Void

  var body: some View {
    HStack(spacing: .contentGap) {
      Button(action: onSelectTimer) {
        TimerRing(progress: presenter.progress, diameter: 22, strokeWidth: 3)
      }
      .buttonStyle(.plain)
      .help(AppLabels.Tab.timer.title)
      .accessibilityLabel(AppLabels.Tab.timer.title)

      if selectionStore.activeTask == nil {
        countdown(secondary: false)
      } else {
        ActiveTaskView(
          engine: engine, selectionStore: selectionStore, registry: registry, nav: nav,
          errorPresenter: errorPresenter, style: .compact, onSelect: onSelectTimer
        )
        countdown(secondary: true)
      }

      Spacer()

      TimerControlsView(presenter: presenter, size: .compact)
    }
    .padding(.horizontal, .screenPadding)
    .padding(.vertical, .contentGap)
    .background(Color.cardSurface)
  }

  /// The phase + countdown label. `secondary` dims it to sit inline after the active task's
  /// title; otherwise it renders `.primary`, the no-task line shown on its own.
  private func countdown(secondary: Bool) -> some View {
    Button(action: onSelectTimer) {
      Text("\(presenter.phaseName) · \(presenter.label)")
        .font(.timerPhaseLabel.monospacedDigit())
        .foregroundStyle(secondary ? .secondary : .primary)
        .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .help(AppLabels.Tab.timer.title)
  }
}

#Preview {
  let engine = SessionEngine()
  let settings = AppSettings()
  let registry = ProviderRegistry()
  let selectionStore = TaskSelectionStore()
  selectionStore.select(
    TaskItem(
      id: TaskRef(providerID: "adhoc", nativeID: UUID().uuidString),
      title: "Draft window-first design doc",
      notes: nil,
      format: .plainText,
      priority: .high,
      dueDate: nil,
      scheduledDate: nil,
      startDate: nil,
      list: nil,
      section: nil,
      sourceURL: nil,
      completedAt: nil,
      createdAt: Date()
    )
  )
  return TimerStripView(
    presenter: TimerPresenter(engine: engine, settings: settings),
    engine: engine,
    selectionStore: selectionStore,
    registry: registry,
    nav: MainNavigation(
      settings: settings, selectionStore: SelectionStore(registry: registry),
      statsViewModel: .preview),
    errorPresenter: ErrorPresenter()
  ) {}
  .frame(width: 560)
}
