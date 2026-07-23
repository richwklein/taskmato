//
//  TimerPresenterTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

@MainActor
struct TimerPresenterTests {

  /// Builds isolated settings with the given phase lengths (in minutes).
  private func makeSettings(focus: Int = 25, short: Int = 5, long: Int = 15) -> AppSettings {
    let settings = AppSettings(defaults: UserDefaults(suiteName: UUID().uuidString)!)
    settings.focusMinutes = focus
    settings.shortBreakMinutes = short
    settings.longBreakMinutes = long
    return settings
  }

  // MARK: - Display

  @Test func labelWhenIdleShowsConfiguredFocusDuration() {
    let presenter = TimerPresenter(engine: SessionEngine(), settings: makeSettings(focus: 25))
    #expect(presenter.label == "25:00")
  }

  @Test func labelWhileActiveReflectsTimeRemaining() {
    var now = Date(timeIntervalSinceReferenceDate: 0)
    let engine = SessionEngine(now: { now })
    let presenter = TimerPresenter(engine: engine, settings: makeSettings(focus: 1))
    presenter.start()
    now = now.addingTimeInterval(20)
    presenter.pause()
    #expect(presenter.label == "00:40")
  }

  @Test func progressIsFullWhenIdle() {
    let presenter = TimerPresenter(engine: SessionEngine(), settings: makeSettings())
    #expect(presenter.progress == 1.0)
  }

  @Test func progressReflectsElapsedFraction() {
    var now = Date(timeIntervalSinceReferenceDate: 0)
    let engine = SessionEngine(now: { now })
    let presenter = TimerPresenter(engine: engine, settings: makeSettings(focus: 1))
    presenter.start()
    now = now.addingTimeInterval(15)
    presenter.pause()
    #expect(presenter.progress == 0.75)
  }

  @Test func idleReportsReadyLabelAndCannotStop() {
    let presenter = TimerPresenter(engine: SessionEngine(), settings: makeSettings())
    #expect(presenter.isIdle)
    #expect(!presenter.canStop)
    #expect(presenter.phaseName == SessionPhase.focus.idleLabel)
  }

  // MARK: - Intents

  @Test func startFromIdleBeginsFocus() {
    let presenter = TimerPresenter(engine: SessionEngine(), settings: makeSettings())
    presenter.start()
    #expect(presenter.isRunning)
    #expect(presenter.phaseName == SessionPhase.focus.displayName)
  }

  @Test func startAppliesSettingsDurationsToEngine() {
    let engine = SessionEngine(focusDuration: 99)
    let presenter = TimerPresenter(engine: engine, settings: makeSettings(focus: 1))
    presenter.start()
    #expect(engine.focusDuration == 60)
    #expect(engine.timeRemaining == 60)
  }

  @Test func skipFromFocusStartsBreak() {
    let presenter = TimerPresenter(engine: SessionEngine(), settings: makeSettings())
    presenter.start()
    presenter.skip()
    #expect(presenter.phaseName == SessionPhase.shortBreak.displayName)
  }

  @Test func pauseThenResumeReturnsToRunning() {
    let presenter = TimerPresenter(engine: SessionEngine(), settings: makeSettings())
    presenter.start()
    presenter.pause()
    #expect(presenter.isPaused)
    presenter.resume()
    #expect(presenter.isRunning)
  }

  @Test func stopReturnsToIdle() {
    let presenter = TimerPresenter(engine: SessionEngine(), settings: makeSettings())
    presenter.start()
    presenter.stop()
    #expect(presenter.isIdle)
    #expect(!presenter.canStop)
  }
}
