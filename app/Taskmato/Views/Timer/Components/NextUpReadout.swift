//
//  NextUpReadout.swift
//  Taskmato
//

import SwiftUI

/// The staged focus length shown beneath the ring's countdown (design doc "stage the next
/// focus", D-d).
///
/// Renders only while a task is staged; collapses rather than reserving blank space, so the
/// countdown shifts by one line when the line appears (an accepted deviation from #590's AC 4).
/// Shows the length only — `settings.focusMinutes`, read live — never the staged task's name:
/// design doc 0009 already rejected task names in the ring on layout grounds (titles are
/// unbounded; the ring is 180 pt). The task name renders in ``ActiveTaskView`` instead, which has
/// room.
struct NextUpReadout: View {

  /// Supplies whether a task is staged and the live focus length to display.
  var nextUpPresenter: NextUpPresenter

  var body: some View {
    if nextUpPresenter.showsNextUp {
      Text(AppLabels.NextUp.focusLength(minutes: nextUpPresenter.nextFocusMinutes))
        .font(.timerPhaseLabel)
        .foregroundStyle(.secondary)
        .accessibilityLabel(AppLabels.Accessibility.nextFocusLength)
        .accessibilityValue("\(nextUpPresenter.nextFocusMinutes) min")
    }
  }
}

#if DEBUG
  #Preview {
    let engine = SessionEngine()
    let settings = AppSettings()
    let selectionStore = TaskSelectionStore()
    selectionStore.stage(
      TaskItem(
        id: TaskRef(providerID: "adhoc", nativeID: UUID().uuidString),
        title: "Draft the proposal",
        notes: nil,
        format: .plainText,
        priority: .medium,
        dueDate: nil,
        scheduledDate: nil,
        startDate: nil,
        list: nil,
        section: nil,
        sourceURL: nil,
        completedAt: nil,
        createdAt: Date()
      ))
    return NextUpReadout(
      nextUpPresenter: NextUpPresenter(
        presenter: TimerPresenter(engine: engine, settings: settings),
        selectionStore: selectionStore, settings: settings)
    )
    .padding()
  }
#endif
