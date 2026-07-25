//
//  TimerStripView.swift
//  Taskmato
//

import SwiftUI

/// A compact session bar pinned below the detail column while a session is non-idle.
///
/// Keeps the countdown and core controls visible from any non-Timer destination: a mini
/// progress ring, the phase and countdown, the active task, and the shared pause/resume ·
/// skip · stop controls. Clicking the readout jumps to the Timer destination. The window
/// gates visibility via ``SessionIndicators``; this view assumes it is only shown when
/// non-idle, so its controls never surface Start.
struct TimerStripView: View {

  /// The presenter supplying timer display values and receiving control intents.
  let presenter: TimerPresenter
  /// The store naming the active task shown beneath the countdown.
  var selectionStore: TaskSelectionStore
  /// Invoked when the user clicks the readout to jump to the Timer surface.
  var onSelectTimer: () -> Void

  var body: some View {
    HStack(spacing: .groupGap) {
      Button(action: onSelectTimer) {
        readout
      }
      .buttonStyle(.plain)

      Spacer()

      TimerControlsView(presenter: presenter, size: .compact)
    }
    .padding(.horizontal, .screenPadding)
    .padding(.vertical, .contentGap)
    .background(Color.cardSurface)
  }

  /// The clickable readout: a mini ring beside the phase/countdown and active task.
  private var readout: some View {
    HStack(spacing: .contentGap) {
      TimerRing(progress: presenter.progress, diameter: 22, strokeWidth: 3)

      VStack(alignment: .leading, spacing: .stackTight) {
        Text("\(presenter.phaseName) — \(presenter.label)")
          .font(.timerPhaseLabel.monospacedDigit())

        if let task = selectionStore.activeTask {
          Text(activeTaskDisplayTitle(for: task))
            .font(.taskMetadata)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
      }
    }
    .contentShape(.rect)
  }
}

#Preview {
  let engine = SessionEngine()
  let settings = AppSettings()
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
    selectionStore: selectionStore
  ) {}
  .frame(width: 560)
}
