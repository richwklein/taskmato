//
//  TimerView.swift
//  Taskmato
//
//  Created by Richard Klein on 5/2/26.
//

import SwiftUI

/// The compact popover view shown when the user clicks the menu bar item.
///
/// Provides quick timer controls and a button to open the main application window.
struct TimerView: View {

  var engine: SessionEngine
  var settings: AppSettings
  var store: SessionStore
  var selectionStore: TaskSelectionStore
  var registry: TaskRegistry
  /// The phase to start when the user presses Start from idle.
  var nextStartPhase: SessionPhase
  /// The break type to use when skipping from a focus session.
  var nextBreakPhase: SessionPhase

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
          NSApp.activate(ignoringOtherApps: true)
          openWindow(id: "main")
          DispatchQueue.main.async { popover?.close() }
        } label: {
          Image(systemName: "arrow.up.forward.app")
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help("Open \(Bundle.main.appName)")
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
        .padding(.bottom, 12)

      Divider()
        .padding(.horizontal, 16)

      if selectionStore.activeTask != nil {
        ActiveTaskView(engine: engine, selectionStore: selectionStore, registry: registry)
      } else {
        Button {
          let popover = NSApp.keyWindow
          NSApp.activate(ignoringOtherApps: true)
          openWindow(id: "main")
          NotificationCenter.default.post(name: .browseTasksAndPick, object: nil)
          DispatchQueue.main.async { popover?.close() }
        } label: {
          Label("Browse Tasks…", systemImage: "checklist")
            .font(.caption)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
      }

      Divider()
        .padding(.horizontal, 16)

      Button {
        let popover = NSApp.keyWindow
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: "main")
        NotificationCenter.default.post(name: .showStatsTab, object: nil)
        DispatchQueue.main.async { popover?.close() }
      } label: {
        SessionStatsView(count: store.todayFocusCount(), minutes: store.todayFocusMinutes())
      }
      .buttonStyle(.plain)
      .padding(.horizontal, 16)
      .padding(.vertical, 10)
    }
    .frame(width: 280)
    .onReceive(NotificationCenter.default.publisher(for: .openMainWindow)) { _ in
      NSApp.activate(ignoringOtherApps: true)
      openWindow(id: "main")
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
          .disabled(selectionStore.activeTask == nil)
          .help(selectionStore.activeTask == nil ? "Select a task before starting" : "")
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
  TimerView(
    engine: SessionEngine(),
    settings: AppSettings(),
    store: SessionStore(),
    selectionStore: TaskSelectionStore(),
    registry: TaskRegistry(),
    nextStartPhase: .focus,
    nextBreakPhase: .shortBreak
  )
}
