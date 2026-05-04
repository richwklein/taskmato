//
//  TimerView.swift
//  Taskmato
//
//  Created by Richard Klein on 5/2/26.
//

import SwiftUI

/// The main popover view shown when the user clicks the menu bar item.
struct TimerView: View {

  var engine: SessionEngine
  var settings: AppSettings
  var store: SessionStore
  /// The phase to start when the user presses Start from idle.
  var nextStartPhase: SessionPhase
  /// The break type to use when skipping from a focus session.
  var nextBreakPhase: SessionPhase

  @Environment(\.openSettings) private var openSettings

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Spacer()
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
      }
      .padding(.horizontal, 16)
      .padding(.top, 12)
      .padding(.bottom, 8)

      CircularTimerView(
        progress: progress,
        label: formattedTimeRemaining,
        phase: phaseName
      )

      controls
        .frame(height: 44)
        .padding(.top, 16)

      Divider()
        .padding(.horizontal, 16)

      SessionStatsView(count: store.todayFocusCount(), minutes: store.todayFocusMinutes())
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
    .frame(width: 280)
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

/// A circular progress ring with a countdown label and phase name centered inside.
private struct CircularTimerView: View {

  /// Fraction of time remaining, from 1.0 (full) down to 0.0 (elapsed).
  let progress: Double
  /// The formatted time string displayed in the center, e.g. `"24:59"`.
  let label: String
  /// The phase name displayed below the time, e.g. `"Focus"`.
  let phase: String

  private let ringDiameter: CGFloat = 180
  private let strokeWidth: CGFloat = 10

  var body: some View {
    ZStack {
      Circle()
        .stroke(Color.secondary.opacity(0.2), lineWidth: strokeWidth)

      // Elapsed arc grows clockwise from 12 o'clock as time passes.
      Circle()
        .trim(from: 0, to: 1 - progress)
        .stroke(
          Color.accentColor,
          style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
        )
        .rotationEffect(.degrees(-90))
        .animation(.linear(duration: 1), value: progress)

      VStack(spacing: 4) {
        Text(label)
          .font(.system(size: 36, weight: .light, design: .monospaced))
          .foregroundStyle(.primary)
        Text(phase)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
    }
    .frame(width: ringDiameter, height: ringDiameter)
  }
}

/// A compact icon-only button used in the timer controls row.
private struct ControlButton: View {

  let label: String
  let icon: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Label(label, systemImage: icon)
        .labelStyle(.iconOnly)
        .frame(width: 32, height: 32)
    }
    .buttonStyle(.bordered)
    .help(label)
  }
}

/// A compact summary row showing today's focus session count and total focused time.
private struct SessionStatsView: View {

  /// Number of completed focus sessions today.
  let count: Int
  /// Total minutes of completed focus time today.
  let minutes: Int

  var body: some View {
    HStack {
      Label(sessionLabel, systemImage: "timer")
      Spacer()
      Label(minuteLabel, systemImage: "clock")
    }
    .font(.caption)
    .foregroundStyle(.secondary)
  }

  private var sessionLabel: String {
    count == 1 ? "1 session today" : "\(count) sessions today"
  }

  private var minuteLabel: String {
    "\(minutes) min focused"
  }
}

#Preview {
  TimerView(
    engine: SessionEngine(),
    settings: AppSettings(),
    store: SessionStore(),
    nextStartPhase: .focus,
    nextBreakPhase: .shortBreak
  )
}
