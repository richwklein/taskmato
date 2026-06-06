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
/// On first appearance, binds the `openWindow` environment action onto ``MainNavigation``
/// and reports the menu-bar scene ready to drain any buffered cold-launch URLs.
struct TimerView: View {

  var engine: SessionEngine
  var settings: AppSettings
  var store: SessionStore
  var selectionStore: TaskSelectionStore
  var registry: TaskRegistry
  var nav: MainNavigation
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
          nav.openMainWindow()
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
        ActiveTaskView(engine: engine, selectionStore: selectionStore, registry: registry, nav: nav)
      } else {
        Button {
          let popover = NSApp.keyWindow
          nav.browseTasksAndPick()
          nav.openMainWindow()
          DispatchQueue.main.async { popover?.close() }
        } label: {
          Label(AppLabels.View.browseTask.title, systemImage: AppLabels.View.browseTask.systemImage)
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
        nav.showStatsInMainWindow()
        DispatchQueue.main.async { popover?.close() }
      } label: {
        SessionStatsView(count: store.todayFocusCount(), minutes: store.todayFocusMinutes())
      }
      .buttonStyle(.plain)
      .padding(.horizontal, 16)
      .padding(.vertical, 10)
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
  TimerView(
    engine: SessionEngine(),
    settings: AppSettings(),
    store: SessionStore(),
    selectionStore: TaskSelectionStore(),
    registry: TaskRegistry(),
    nav: MainNavigation(settings: AppSettings()),
    nextStartPhase: .focus,
    nextBreakPhase: .shortBreak
  )
}
