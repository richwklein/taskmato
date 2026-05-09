//
//  TimerTabView.swift
//  Taskmato
//

import SwiftUI

/// The timer tab shown in the main application window.
struct TimerTabView: View {

  var engine: SessionEngine
  var settings: AppSettings
  var store: SessionStore
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

      SessionStatsView(count: store.todayFocusCount(), minutes: store.todayFocusMinutes())
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }
  }

  // MARK: - Controls

  private var controls: some View {
    HStack(spacing: 12) {
      if engine.isRunning {
        ControlButton(label: "Pause", icon: "pause.fill") { engine.pause() }
      } else if case .paused = engine.state {
        ControlButton(label: "Resume", icon: "play.fill") { engine.resume() }
      } else {
        ControlButton(label: "Start", icon: "play.fill") { startSession() }
      }

      ControlButton(label: "Skip", icon: "forward.fill") { skipPhase() }

      ControlButton(label: "Stop", icon: "stop.fill") { engine.stop() }
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
      switch nextStartPhase {
      case .focus: return "Ready to focus"
      case .shortBreak: return "Short Break"
      case .longBreak: return "Long Break"
      }
    case .running(let phase, _, _), .paused(let phase, _):
      switch phase {
      case .focus: return "Focus"
      case .shortBreak: return "Short Break"
      case .longBreak: return "Long Break"
      }
    }
  }
}

#Preview {
  TimerTabView(
    engine: SessionEngine(),
    settings: AppSettings(),
    store: SessionStore(),
    nextStartPhase: .focus,
    nextBreakPhase: .shortBreak
  )
}
