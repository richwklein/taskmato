//
//  TimerTabView.swift
//  Taskmato
//

import SwiftUI

/// The timer tab shown in the main application window.
struct TimerTabView: View {

  var engine: SessionEngine
  var settings: AppSettings
  var statsViewModel: StatsViewModel
  var selectionStore: TaskSelectionStore
  var registry: TaskRegistry
  var nav: MainNavigation
  /// The phase to start when the user presses Start from idle.
  var nextStartPhase: SessionPhase
  /// The break type to use when skipping from a focus session.
  var nextBreakPhase: SessionPhase

  var body: some View {
    VStack(spacing: 0) {
      Spacer()

      CircularTimerView(
        progress: progress,
        label: formattedTimeRemaining,
        phase: phaseName
      )

      controls
        .frame(height: 44)
        .padding(.top, 20)
        .padding(.bottom, 24)

      Spacer()

      Divider()
        .padding(.horizontal, 24)

      if selectionStore.activeTask != nil {
        ActiveTaskView(
          engine: engine, selectionStore: selectionStore, registry: registry, nav: nav,
          showNotes: true
        )
        .padding(.horizontal, 8)
      } else {
        Button {
          nav.browseTasksAndPick()
        } label: {
          Label(AppLabels.View.browseTask.title, systemImage: AppLabels.View.browseTask.systemImage)
            .font(.caption)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 24)
        .padding(.vertical, 6)
      }

      Divider()
        .padding(.horizontal, 24)

      SessionStatsView(
        count: statsViewModel.todayFocusCount, minutes: statsViewModel.todayFocusMinutes,
        streak: statsViewModel.currentStreak
      )
      .padding(.horizontal, 24)
      .padding(.vertical, 12)
    }
  }

  // MARK: - Controls

  private var controls: some View {
    HStack(spacing: 12) {
      if engine.isRunning {
        ControlButton(
          label: AppLabels.Timer.pause.title,
          icon: AppLabels.Timer.pause.systemImage
        ) { engine.pause() }
      } else if case .paused = engine.state {
        ControlButton(
          label: AppLabels.Timer.resume.title,
          icon: AppLabels.Timer.resume.systemImage
        ) { engine.resume() }
      } else {
        ControlButton(
          label: AppLabels.Timer.start.title,
          icon: AppLabels.Timer.start.systemImage
        ) { startSession() }
        .disabled(selectionStore.activeTask == nil)
        .help(selectionStore.activeTask == nil ? AppLabels.Tooltip.selectTaskFirst : "")
      }

      ControlButton(
        label: AppLabels.Timer.skip.title,
        icon: AppLabels.Timer.skip.systemImage
      ) { skipPhase() }

      ControlButton(
        label: AppLabels.Timer.stop.title,
        icon: AppLabels.Timer.stop.systemImage
      ) { engine.stop() }
      .disabled(engine.state == .idle)
    }
  }

  // MARK: - Actions

  /// Syncs current settings into the engine, then starts the appropriate next phase.
  private func startSession() {
    engine.focusDuration = settings.focusDuration
    engine.shortBreakDuration = settings.shortBreakDuration
    engine.longBreakDuration = settings.longBreakDuration
    engine.start(phase: nextStartPhase)
  }

  /// Syncs current settings into the engine, then skips to the next phase.
  ///
  /// The engine mirrors the current running state: running stays running, paused stays
  /// paused (at the new phase's full duration), and idle queues the next phase.
  private func skipPhase() {
    engine.focusDuration = settings.focusDuration
    engine.shortBreakDuration = settings.shortBreakDuration
    engine.longBreakDuration = settings.longBreakDuration
    engine.skip(nextBreak: nextBreakPhase)
  }

  // MARK: - Helpers

  private var progress: Double {
    switch engine.state {
    case .idle:
      return 1.0
    case .running(_, _, let duration):
      guard duration > 0 else { return 1 }
      return engine.timeRemaining / duration
    case .paused(let phase, _):
      let duration: TimeInterval
      switch phase {
      case .focus: duration = engine.focusDuration
      case .shortBreak: duration = engine.shortBreakDuration
      case .longBreak: duration = engine.longBreakDuration
      }
      guard duration > 0 else { return 1 }
      return engine.timeRemaining / duration
    }
  }

  private var formattedTimeRemaining: String {
    let seconds: Int
    if case .idle = engine.state {
      switch nextStartPhase {
      case .focus: seconds = Int(settings.focusDuration)
      case .shortBreak: seconds = Int(settings.shortBreakDuration)
      case .longBreak: seconds = Int(settings.longBreakDuration)
      }
    } else {
      seconds = Int(engine.timeRemaining)
    }
    return String(format: "%02d:%02d", seconds / 60, seconds % 60)
  }

  private var phaseName: String {
    switch engine.state {
    case .idle:
      return nextStartPhase.idleLabel
    case .running(let phase, _, _), .paused(let phase, _):
      return phase.displayName
    }
  }
}

#Preview {
  TimerTabView(
    engine: SessionEngine(),
    settings: AppSettings(),
    statsViewModel: .preview,
    selectionStore: TaskSelectionStore(),
    registry: TaskRegistry(),
    nav: MainNavigation(settings: AppSettings()),
    nextStartPhase: .focus,
    nextBreakPhase: .shortBreak
  )
}
