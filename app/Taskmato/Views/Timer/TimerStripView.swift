//
//  TimerStripView.swift
//  Taskmato
//

import SwiftUI

/// A compact session bar pinned below the detail column while a session is non-idle.
///
/// Keeps the countdown and core controls visible from any non-Timer destination: the active
/// task, a mini progress ring, the phase and countdown, and the shared pause/resume · skip ·
/// stop controls. When a task is active its title leads the strip on the left; a flexible
/// spacer pushes the timer machinery — a hairline divider walling it off, the ring, and the
/// phase + countdown session-state cluster (`.secondary`) — into a right rail flush against
/// the controls. With no active task the ring and countdown stand alone (`.primary`),
/// right-aligned beside the controls with the divider omitted. Clicking the ring, the
/// countdown, or the task title jumps to the Timer destination; the active task's radio stays
/// a sibling control so completing or clearing mid-session never navigates. The window gates
/// visibility via ``SessionIndicators``; this view assumes it is only shown when non-idle, so
/// its controls never surface Start.
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
      if selectionStore.activeTask != nil {
        ActiveTaskView(
          engine: engine, selectionStore: selectionStore, registry: registry, nav: nav,
          errorPresenter: errorPresenter, style: .compact, onSelect: onSelectTimer
        )
      }

      Spacer()

      if selectionStore.activeTask != nil {
        Divider()
          .frame(height: 22)
          .padding(.horizontal, .contentGap)
      }

      Button(action: onSelectTimer) {
        TimerRing(progress: presenter.progress, diameter: 22, strokeWidth: 3)
      }
      .buttonStyle(.plain)
      .help(AppLabels.Tab.timer.title)
      .accessibilityLabel(AppLabels.Tab.timer.title)

      countdown(secondary: selectionStore.activeTask != nil)

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

#if DEBUG
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
#endif
