//
//  TimerPresenterFocusGateTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

/// Covers D11 of design doc 0010: no intent puts a focus phase on the clock while nothing is
/// tracked, and detaching the tracked task parks a running one.
@MainActor
struct TimerPresenterFocusGateTests {

  private func makeSettings() -> AppSettings {
    let settings = AppSettings(
      store: SettingsStore(defaults: UserDefaults(suiteName: UUID().uuidString)!))
    settings.focusMinutes = 25
    settings.shortBreakMinutes = 5
    settings.longBreakMinutes = 15
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

  /// Builds a presenter over isolated settings and an isolated task store. A task is tracked by
  /// default, since every focus intent is gated on having one to credit the time to.
  private func makePresenter(
    engine: SessionEngine = SessionEngine(),
    activeTaskStore: ActiveTaskStore? = nil
  ) -> TimerPresenter {
    TimerPresenter(
      engine: engine, settings: makeSettings(), activeTaskStore: activeTaskStore ?? makeStore())
  }

  // MARK: - Focus requires a task

  @Test func primaryDisabledWhenIdleWithNoTask() {
    let presenter = makePresenter(activeTaskStore: makeStore(tracked: false))
    #expect(presenter.isIdle)
    #expect(presenter.primaryDisabled)
  }

  @Test func primaryEnabledWhenIdleWithATrackedTask() {
    let presenter = makePresenter()
    #expect(!presenter.primaryDisabled)
  }

  @Test func primaryEnabledWhenIdleWithOnlyAStagedTask() {
    let store = makeStore(tracked: false)
    store.stage(makeTask())
    let presenter = makePresenter(activeTaskStore: store)
    #expect(!presenter.primaryDisabled)  // `began(.focus)` promotes it as the phase opens
  }

  @Test(arguments: [SessionPhase.shortBreak, .longBreak])
  func primaryEnabledWithABreakQueuedAndNoTask(queued: SessionPhase) {
    let engine = SessionEngine()
    let presenter = makePresenter(engine: engine, activeTaskStore: makeStore(tracked: false))
    engine.enqueuePhase(queued)
    #expect(!presenter.primaryDisabled)  // breaks credit no task
  }

  @Test func startIsANoOpWithNoTask() {
    let presenter = makePresenter(activeTaskStore: makeStore(tracked: false))
    presenter.start()
    #expect(presenter.isIdle)
  }

  @Test func primaryDisabledWhenFocusIsPausedAndTheTaskIsCleared() {
    let store = makeStore()
    let presenter = makePresenter(activeTaskStore: store)
    presenter.start()
    presenter.pause()
    store.clearActiveTask()
    #expect(presenter.isPaused)
    #expect(presenter.primaryDisabled)
  }

  @Test func resumeIsANoOpWhenTheTaskWasClearedMidFocus() {
    let store = makeStore()
    let presenter = makePresenter(activeTaskStore: store)
    presenter.start()
    presenter.pause()
    store.clearActiveTask()
    presenter.resume()
    #expect(presenter.isPaused)
    #expect(!presenter.isRunning)
  }

  @Test func resumeIsStillBlockedWhenOnlyATaskIsStaged() {
    let store = makeStore()
    let presenter = makePresenter(activeTaskStore: store)
    presenter.start()
    presenter.pause()
    store.clearActiveTask()
    store.stage(makeTask())
    presenter.resume()
    // Resume yields no `.began`, so a staged task would never be promoted.
    #expect(presenter.isPaused)
  }

  @Test func resumeSucceedsOnceAReplacementTaskIsTracked() {
    let store = makeStore()
    let presenter = makePresenter(activeTaskStore: store)
    presenter.start()
    presenter.pause()
    store.clearActiveTask()
    store.track(makeTask(title: "The next thing"))
    presenter.resume()
    #expect(presenter.isRunning)
  }

  @Test func pausedBreakStillResumesWithNoTask() {
    let engine = SessionEngine()
    let presenter = makePresenter(engine: engine, activeTaskStore: makeStore(tracked: false))
    engine.start(phase: .shortBreak)
    presenter.pause()
    presenter.resume()
    #expect(presenter.isRunning)
  }

  @Test func skipOutOfABreakWithNoTaskAdvancesButParksFocus() {
    let engine = SessionEngine()
    let presenter = makePresenter(engine: engine, activeTaskStore: makeStore(tracked: false))
    engine.start(phase: .shortBreak)
    #expect(presenter.canSkip)
    presenter.skip()
    #expect(presenter.phaseName == SessionPhase.focus.displayName)  // the break did advance
    #expect(presenter.isPaused)  // but focus is not on the clock
    #expect(presenter.primaryDisabled)
  }

  @Test func aParkedSkippedFocusRunsOnceATaskIsTracked() {
    let engine = SessionEngine()
    let store = makeStore(tracked: false)
    let presenter = makePresenter(engine: engine, activeTaskStore: store)
    engine.start(phase: .shortBreak)
    presenter.skip()
    store.track(makeTask())
    presenter.resume()
    #expect(presenter.isRunning)
    #expect(presenter.phaseName == SessionPhase.focus.displayName)
  }

  @Test func skipOutOfABreakWithATrackedTaskStartsFocusRunning() {
    let engine = SessionEngine()
    let presenter = makePresenter(engine: engine)
    engine.start(phase: .shortBreak)
    presenter.skip()
    #expect(presenter.phaseName == SessionPhase.focus.displayName)
    #expect(presenter.isRunning)
  }

  @Test func skipOutOfABreakWithOnlyAStagedTaskStartsFocusRunning() {
    let engine = SessionEngine()
    let store = makeStore(tracked: false)
    store.stage(makeTask())
    let presenter = makePresenter(engine: engine, activeTaskStore: store)
    engine.start(phase: .shortBreak)
    presenter.skip()
    // `began(.focus)` promotes the staged task when the orchestrator drains the yielded event.
    #expect(presenter.isRunning)
  }

  @Test func skipFromAPausedBreakStaysPausedWithNoTask() {
    let engine = SessionEngine()
    let presenter = makePresenter(engine: engine, activeTaskStore: makeStore(tracked: false))
    engine.start(phase: .shortBreak)
    presenter.pause()
    presenter.skip()
    #expect(presenter.isPaused)
    #expect(presenter.phaseName == SessionPhase.focus.displayName)
  }

  @Test func canAlwaysSkipOutOfFocus() {
    let store = makeStore()
    let presenter = makePresenter(activeTaskStore: store)
    presenter.start()
    store.clearActiveTask()
    #expect(presenter.canSkip)  // skipping focus enters a break, which needs no task
  }

  // MARK: - Untracked focus is paused

  @Test func pauseUntrackedFocusPausesARunningFocusPhaseWithNoTask() {
    let store = makeStore()
    let presenter = makePresenter(activeTaskStore: store)
    presenter.start()
    store.clearActiveTask()
    presenter.pauseUntrackedFocus()
    #expect(presenter.isPaused)
  }

  @Test func pauseUntrackedFocusLeavesATrackedPhaseRunning() {
    let presenter = makePresenter()
    presenter.start()
    presenter.pauseUntrackedFocus()
    #expect(presenter.isRunning)
  }

  @Test func pauseUntrackedFocusLeavesABreakRunning() {
    let engine = SessionEngine()
    let presenter = makePresenter(engine: engine, activeTaskStore: makeStore(tracked: false))
    engine.start(phase: .shortBreak)
    presenter.pauseUntrackedFocus()
    #expect(presenter.isRunning)
  }

  // MARK: - Pending continuation (D9 of design doc 0010)

  @Test func resumeClearsAPendingContinuation() {
    let store = makeStore()
    let presenter = makePresenter(activeTaskStore: store)
    presenter.start()
    presenter.pause()
    store.markPendingContinuation()
    presenter.resume()
    #expect(!store.isPendingContinuation)
  }

  @Test func stopClearsAPendingContinuation() {
    let store = makeStore()
    let presenter = makePresenter(activeTaskStore: store)
    presenter.start()
    presenter.pause()
    store.markPendingContinuation()
    presenter.stop()
    #expect(!store.isPendingContinuation)
  }

  @Test func aBlockedResumeLeavesThePendingContinuationArmed() {
    let store = makeStore()
    let presenter = makePresenter(activeTaskStore: store)
    presenter.start()
    presenter.pause()
    store.clearActiveTask()
    store.markPendingContinuation()
    presenter.resume()
    // The handoff is still waiting on a task, so the flag must survive to fire on that select.
    #expect(store.isPendingContinuation)
  }
}
