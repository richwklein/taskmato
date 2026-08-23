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
    let settings = AppSettings(
      store: SettingsStore(defaults: UserDefaults(suiteName: UUID().uuidString)!))
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

  // MARK: - Accessibility

  @Test func accessibilityValueWhenIdleShowsConfiguredFocusDuration() {
    let presenter = TimerPresenter(engine: SessionEngine(), settings: makeSettings(focus: 25))
    #expect(presenter.accessibilityValue == "Ready to focus, 25 minutes")
  }

  // `pause()` is the only way to obtain a deterministic `timeRemaining` read in these tests
  // (mirroring `labelWhileActiveReflectsTimeRemaining` above), so every case below observes
  // the presenter mid-pause — hence the ", paused" segment in each expected value.

  @Test func accessibilityValueAtOneMinuteRemainingUsesSingularUnit() {
    var now = Date(timeIntervalSinceReferenceDate: 0)
    let engine = SessionEngine(now: { now })
    let presenter = TimerPresenter(engine: engine, settings: makeSettings(focus: 1))
    presenter.start()
    presenter.pause()
    #expect(presenter.accessibilityValue == "Focus, paused, 1 minute remaining")
  }

  @Test func accessibilityValueUnderAMinuteIsVague() {
    var now = Date(timeIntervalSinceReferenceDate: 0)
    let engine = SessionEngine(now: { now })
    let presenter = TimerPresenter(engine: engine, settings: makeSettings(focus: 1))
    presenter.start()
    now = now.addingTimeInterval(20)
    presenter.pause()
    #expect(presenter.accessibilityValue == "Focus, paused, less than a minute remaining")
  }

  @Test func accessibilityValueInFinalTenSecondsCountsDown() {
    var now = Date(timeIntervalSinceReferenceDate: 0)
    let engine = SessionEngine(now: { now })
    let presenter = TimerPresenter(engine: engine, settings: makeSettings(focus: 1))
    presenter.start()
    now = now.addingTimeInterval(50)
    presenter.pause()
    #expect(presenter.accessibilityValue == "Focus, paused, 10 seconds remaining")
  }

  @Test func accessibilityValueAtOneSecondRemainingUsesSingularUnit() {
    var now = Date(timeIntervalSinceReferenceDate: 0)
    let engine = SessionEngine(now: { now })
    let presenter = TimerPresenter(engine: engine, settings: makeSettings(focus: 1))
    presenter.start()
    now = now.addingTimeInterval(59)
    presenter.pause()
    #expect(presenter.accessibilityValue == "Focus, paused, 1 second remaining")
  }

  @Test func accessibilityValueWhenPausedIncludesPausedState() {
    var now = Date(timeIntervalSinceReferenceDate: 0)
    let engine = SessionEngine(now: { now })
    let presenter = TimerPresenter(engine: engine, settings: makeSettings(focus: 25))
    presenter.start()
    now = now.addingTimeInterval(60)
    presenter.pause()
    #expect(presenter.accessibilityValue == "Focus, paused, 24 minutes remaining")
  }

  @Test func accessibilityValueWhileRunningOmitsPausedState() {
    // A freshly started session is running (not paused) with `timeRemaining` at the full
    // duration, so no advance/pause is needed to read it deterministically.
    let engine = SessionEngine(now: { Date(timeIntervalSinceReferenceDate: 0) })
    let presenter = TimerPresenter(engine: engine, settings: makeSettings(focus: 1))
    presenter.start()
    #expect(presenter.isRunning)
    #expect(presenter.accessibilityValue == "Focus, 1 minute remaining")
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

  // MARK: - Focus presets

  @Test func focusPresetsMirrorsSettingsWhenCurrentValueIsAPreset() {
    let settings = makeSettings(focus: 25)
    settings.focusPresets = [15, 25, 45, 60]
    let presenter = TimerPresenter(engine: SessionEngine(), settings: settings)
    #expect(presenter.focusPresets == [15, 25, 45, 60])
    #expect(presenter.selectedFocusMinutes == 25)
  }

  @Test func focusPresetsPrependsCustomFocusMinutesNotInTheList() {
    let settings = makeSettings(focus: 30)
    settings.focusPresets = [15, 25, 45, 60]
    let presenter = TimerPresenter(engine: SessionEngine(), settings: settings)
    #expect(presenter.focusPresets == [15, 25, 30, 45, 60])
    #expect(presenter.selectedFocusMinutes == 30)
  }

  @Test func showsFocusPresetPickerIsFalseWithASinglePreset() {
    let settings = makeSettings(focus: 25)
    settings.focusPresets = [25]
    let presenter = TimerPresenter(engine: SessionEngine(), settings: settings)
    #expect(!presenter.showsFocusPresetPicker)
  }

  @Test func showsFocusPresetPickerIsTrueWithMoreThanOnePreset() {
    let settings = makeSettings(focus: 25)
    settings.focusPresets = [25, 45]
    let presenter = TimerPresenter(engine: SessionEngine(), settings: settings)
    #expect(presenter.showsFocusPresetPicker)
  }

  @Test func showsFocusPresetPickerIsTrueWhenCustomFocusMinutesAddsASecondValue() {
    let settings = makeSettings(focus: 30)
    settings.focusPresets = [25]
    let presenter = TimerPresenter(engine: SessionEngine(), settings: settings)
    #expect(presenter.showsFocusPresetPicker)
  }

  @Test func selectFocusPresetUpdatesSelectionAndLabelWhileIdle() {
    let presenter = TimerPresenter(engine: SessionEngine(), settings: makeSettings(focus: 25))
    presenter.selectFocusPreset(45)
    #expect(presenter.selectedFocusMinutes == 45)
    #expect(presenter.label == "45:00")
  }

  @Test func selectFocusPresetIsNoOpWhileRunning() {
    let presenter = TimerPresenter(engine: SessionEngine(), settings: makeSettings(focus: 25))
    presenter.start()
    presenter.selectFocusPreset(45)
    #expect(presenter.selectedFocusMinutes == 25)
  }

  @Test func selectFocusPresetIsNoOpWhilePaused() {
    let presenter = TimerPresenter(engine: SessionEngine(), settings: makeSettings(focus: 25))
    presenter.start()
    presenter.pause()
    presenter.selectFocusPreset(45)
    #expect(presenter.selectedFocusMinutes == 25)
  }

  @Test(arguments: [SessionPhase.shortBreak, .longBreak])
  func showsFocusPresetPickerIsFalseWithABreakQueued(queued: SessionPhase) {
    let engine = SessionEngine()
    let settings = makeSettings(focus: 25)
    settings.focusPresets = [15, 25, 45, 60]
    let presenter = TimerPresenter(engine: engine, settings: settings)
    engine.enqueuePhase(queued)
    #expect(!presenter.canSelectFocusPreset)
    #expect(!presenter.showsFocusPresetPicker)
  }

  @Test func showsFocusPresetPickerIsTrueWhenFocusIsExplicitlyQueued() {
    let engine = SessionEngine()
    let settings = makeSettings(focus: 25)
    settings.focusPresets = [15, 25, 45, 60]
    let presenter = TimerPresenter(engine: engine, settings: settings)
    engine.enqueuePhase(.focus)
    #expect(presenter.canSelectFocusPreset)
    #expect(presenter.showsFocusPresetPicker)
  }

  @Test func selectFocusPresetIsNoOpWithABreakQueued() {
    let engine = SessionEngine()
    let settings = makeSettings(focus: 25, short: 5)
    settings.focusPresets = [15, 25, 45, 60]
    let presenter = TimerPresenter(engine: engine, settings: settings)
    engine.enqueuePhase(.shortBreak)
    presenter.selectFocusPreset(45)
    #expect(presenter.selectedFocusMinutes == 25)
    #expect(presenter.label == "05:00")
  }

  @Test func showsFocusPresetPickerReturnsAfterSkipConsumesQueuedBreak() {
    let engine = SessionEngine()
    let settings = makeSettings(focus: 25)
    settings.focusPresets = [15, 25, 45, 60]
    let presenter = TimerPresenter(engine: engine, settings: settings)
    engine.enqueuePhase(.shortBreak)
    #expect(!presenter.showsFocusPresetPicker)
    presenter.skip()
    #expect(presenter.showsFocusPresetPicker)
    presenter.selectFocusPreset(45)
    #expect(presenter.selectedFocusMinutes == 45)
  }

  @Test func showsFocusPresetPickerIsFalseWhileRunning() {
    let settings = makeSettings(focus: 25)
    settings.focusPresets = [15, 25, 45, 60]
    let presenter = TimerPresenter(engine: SessionEngine(), settings: settings)
    presenter.start()
    #expect(!presenter.showsFocusPresetPicker)
  }

  @Test func showsFocusPresetPickerIsFalseWhilePaused() {
    let settings = makeSettings(focus: 25)
    settings.focusPresets = [15, 25, 45, 60]
    let presenter = TimerPresenter(engine: SessionEngine(), settings: settings)
    presenter.start()
    presenter.pause()
    #expect(!presenter.showsFocusPresetPicker)
  }

  // MARK: - Staging the next focus

  // There is no staged-length state: the "Focus Next ▸" gesture writes `settings.focusMinutes`
  // and the engine picks it up at the next boundary via `applyDurations(from:)` (design doc
  // "stage the next focus", D-b). These cover that path end to end, standing in for the gesture.

  @Test func stagedFocusLengthLeavesTheBreakCountdownAlone() {
    let engine = SessionEngine()
    let settings = makeSettings(focus: 25, short: 5)
    let presenter = TimerPresenter(engine: engine, settings: settings)
    engine.enqueuePhase(.shortBreak)
    settings.focusMinutes = 45
    #expect(presenter.selectedFocusMinutes == 45)
    #expect(presenter.label == "05:00")
  }

  @Test func stagedFocusLengthAppliesToTheFocusPhaseAfterTheBreak() {
    let engine = SessionEngine()
    let settings = makeSettings(focus: 25, short: 5)
    let presenter = TimerPresenter(engine: engine, settings: settings)
    engine.enqueuePhase(.shortBreak)
    settings.focusMinutes = 45
    presenter.skip()  // idle-skip consumes the queued break and queues focus
    #expect(presenter.label == "45:00")
    presenter.start()
    #expect(engine.focusDuration == 45 * 60)
  }

  @Test func stagedFocusLengthAppliesAfterAPhaseStagedMidSession() {
    let engine = SessionEngine()
    let settings = makeSettings(focus: 25, short: 5)
    let presenter = TimerPresenter(engine: engine, settings: settings)
    presenter.start()
    settings.focusMinutes = 45  // staged while focus is live; must not resize the running phase
    #expect(engine.focusDuration == 25 * 60)
    presenter.skip()
    #expect(engine.focusDuration == 45 * 60)
  }

  // MARK: - Enablement

  @Test func canSkipDisabledWhenIdleWithNothingQueued() {
    let presenter = TimerPresenter(engine: SessionEngine(), settings: makeSettings())
    #expect(presenter.isIdle)
    #expect(!presenter.isRunning)
    #expect(!presenter.isPaused)
    #expect(!presenter.canStop)
    #expect(!presenter.canSkip)
  }

  @Test func canSkipEnabledWhenIdleWithBreakQueued() {
    let engine = SessionEngine()
    let presenter = TimerPresenter(engine: engine, settings: makeSettings())
    engine.enqueuePhase(.shortBreak)
    #expect(presenter.isIdle)
    #expect(!presenter.canStop)
    #expect(presenter.canSkip)
  }

  @Test func canSkipDisabledWhenIdleWithFocusQueued() {
    let engine = SessionEngine()
    let presenter = TimerPresenter(engine: engine, settings: makeSettings())
    engine.enqueuePhase(.focus)
    #expect(presenter.isIdle)
    #expect(!presenter.canStop)
    #expect(!presenter.canSkip)
  }

  @Test func canSkipAndCanStopEnabledWhenRunning() {
    let engine = SessionEngine()
    let presenter = TimerPresenter(engine: engine, settings: makeSettings())
    presenter.start()
    #expect(presenter.isRunning)
    #expect(!presenter.isPaused)
    #expect(presenter.canStop)
    #expect(presenter.canSkip)
  }

  @Test func canSkipAndCanStopEnabledWhenPaused() {
    let engine = SessionEngine()
    let presenter = TimerPresenter(engine: engine, settings: makeSettings())
    presenter.start()
    presenter.pause()
    #expect(presenter.isPaused)
    #expect(!presenter.isRunning)
    #expect(presenter.canStop)
    #expect(presenter.canSkip)
  }

  @Test func canSkipAndCanStopDisabledAfterStoppingBackToIdle() {
    let engine = SessionEngine()
    let presenter = TimerPresenter(engine: engine, settings: makeSettings())
    presenter.start()
    presenter.stop()
    #expect(!presenter.canStop)
    #expect(!presenter.canSkip)
  }
}
