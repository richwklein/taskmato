//
//  FocusHandoffCoordinatorTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

/// Covers the start-vs-resume decisions ``FocusHandoffCoordinator`` makes, gated on
/// `startFocusOnTaskPick`. The D11 task gate itself is `TimerPresenterFocusGateTests`'s
/// responsibility, not re-tested here.
@MainActor
struct FocusHandoffCoordinatorTests {

  private func makeSettings(startFocusOnTaskPick: Bool = true) -> AppSettings {
    let settings = AppSettings(
      store: SettingsStore(defaults: UserDefaults(suiteName: UUID().uuidString)!))
    settings.focusMinutes = 25
    settings.shortBreakMinutes = 5
    settings.longBreakMinutes = 15
    settings.startFocusOnTaskPick = startFocusOnTaskPick
    return settings
  }

  private func makeTask(title: String = "Write the spec") -> TaskItem {
    TaskItem(
      id: TaskRef(providerID: "stub", nativeID: UUID().uuidString), title: title, notes: nil,
      format: .plainText, priority: .none, dueDate: nil, scheduledDate: nil, startDate: nil,
      list: nil, section: nil, sourceURL: nil, completedAt: nil, createdAt: Date())
  }

  /// Builds an isolated task store, tracking a task unless `tracked` is false.
  private func makeStore(tracked: Bool = true) -> ActiveTaskStore {
    let store = ActiveTaskStore(
      store: SettingsStore(defaults: UserDefaults(suiteName: UUID().uuidString)!))
    if tracked { store.track(makeTask()) }
    return store
  }

  private func makeCoordinator(
    engine: SessionEngine = SessionEngine(),
    activeTaskStore: ActiveTaskStore? = nil,
    settings: AppSettings? = nil
  ) -> (coordinator: FocusHandoffCoordinator, presenter: TimerPresenter) {
    let resolvedSettings = settings ?? makeSettings()
    let presenter = TimerPresenter(
      engine: engine, settings: resolvedSettings,
      activeTaskStore: activeTaskStore ?? makeStore())
    return (
      FocusHandoffCoordinator(presenter: presenter, settings: resolvedSettings), presenter
    )
  }

  // MARK: - startFocusOnPick

  @Test func startFocusOnPickStartsFocusWhenIdleWithFocusNextAndATaskTracked() {
    let (coordinator, presenter) = makeCoordinator()
    coordinator.startFocusOnPick()
    #expect(presenter.isRunning)
  }

  @Test func startFocusOnPickLeavesAQueuedBreakUntouched() {
    let engine = SessionEngine()
    let (coordinator, presenter) = makeCoordinator(engine: engine)
    engine.enqueuePhase(.shortBreak)
    coordinator.startFocusOnPick()
    #expect(presenter.isIdle)
    #expect(engine.queuedPhase == .shortBreak)
  }

  @Test func startFocusOnPickLeavesARunningPhaseUntouched() {
    let engine = SessionEngine()
    let (coordinator, presenter) = makeCoordinator(engine: engine)
    presenter.start()
    coordinator.startFocusOnPick()
    #expect(presenter.isRunning)
  }

  @Test func startFocusOnPickLeavesAPausedPhaseUntouched() {
    let engine = SessionEngine()
    let (coordinator, presenter) = makeCoordinator(engine: engine)
    presenter.start()
    presenter.pause()
    coordinator.startFocusOnPick()
    #expect(presenter.isPaused)
  }

  @Test func startFocusOnPickIsANoOpWithTheToggleOff() {
    let settings = makeSettings(startFocusOnTaskPick: false)
    let (coordinator, presenter) = makeCoordinator(settings: settings)
    coordinator.startFocusOnPick()
    #expect(presenter.isIdle)
  }

  // MARK: - resumeAfterHandoff

  @Test func resumeAfterHandoffResumesAPausedFocusPhase() {
    let engine = SessionEngine()
    let (coordinator, presenter) = makeCoordinator(engine: engine)
    presenter.start()
    presenter.pause()
    coordinator.resumeAfterHandoff()
    #expect(presenter.isRunning)
  }

  @Test func resumeAfterHandoffStaysIdle() {
    // The deliberate asymmetry: completing with a staged task never *starts* focus from idle.
    let (coordinator, presenter) = makeCoordinator()
    coordinator.resumeAfterHandoff()
    #expect(presenter.isIdle)
  }

  @Test func resumeAfterHandoffIsANoOpWithTheToggleOff() {
    let settings = makeSettings(startFocusOnTaskPick: false)
    let engine = SessionEngine()
    let store = makeStore()
    let presenter = TimerPresenter(engine: engine, settings: settings, activeTaskStore: store)
    let coordinator = FocusHandoffCoordinator(presenter: presenter, settings: settings)
    presenter.start()
    presenter.pause()
    coordinator.resumeAfterHandoff()
    #expect(presenter.isPaused)
  }

  /// `AppComposition` gates `showTimerInMainWindow()` on this return value, so a declined handoff
  /// must report `false` — D9 of design doc 0010 couples returning to the Timer with the resume,
  /// and navigating anyway would yank the window on a gesture the user opted out of.
  @Test func resumeAfterHandoffReportsWhetherItActed() {
    let (acting, _) = makeCoordinator()
    #expect(acting.resumeAfterHandoff() == true)

    let settings = makeSettings(startFocusOnTaskPick: false)
    let store = makeStore()
    let presenter = TimerPresenter(
      engine: SessionEngine(), settings: settings, activeTaskStore: store)
    let declining = FocusHandoffCoordinator(presenter: presenter, settings: settings)
    #expect(declining.resumeAfterHandoff() == false)
  }
}
