//
//  SessionEngineTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

@MainActor
struct SessionEngineTests {

  @Test func startTransitionsToFocus() {
    let engine = SessionEngine()
    engine.start()
    guard case .running(let phase, _, _) = engine.state else {
      Issue.record("Expected running state")
      return
    }
    #expect(phase == .focus)
  }

  @Test func pauseCapturesRemainingTime() {
    var currentTime = Date(timeIntervalSinceReferenceDate: 0)
    let engine = SessionEngine(focusDuration: 60, now: { currentTime })
    engine.start()
    currentTime = currentTime.addingTimeInterval(10)
    engine.pause()
    guard case .paused(_, let remaining) = engine.state else {
      Issue.record("Expected paused state")
      return
    }
    #expect(remaining == 50)
  }

  @Test func resumeRestoresFocusPhase() {
    let engine = SessionEngine()
    engine.start()
    engine.pause()
    engine.resume()
    guard case .running(let phase, _, _) = engine.state else {
      Issue.record("Expected running state")
      return
    }
    #expect(phase == .focus)
  }

  @Test func resumePreservesRemainingTime() {
    var currentTime = Date(timeIntervalSinceReferenceDate: 0)
    let engine = SessionEngine(focusDuration: 60, now: { currentTime })
    engine.start()
    currentTime = currentTime.addingTimeInterval(10)
    engine.pause()
    engine.resume()
    #expect(engine.timeRemaining == 50)
  }

  @Test func stopResetsToIdle() {
    let engine = SessionEngine()
    engine.start()
    engine.stop()
    #expect(engine.state == .idle)
  }

  @Test func applyDurationsCopiesSettingsIntoEngine() {
    let engine = SessionEngine(focusDuration: 1, shortBreakDuration: 1, longBreakDuration: 1)
    let settings = AppSettings(
      store: SettingsStore(defaults: UserDefaults(suiteName: UUID().uuidString)!))
    settings.focusMinutes = 25
    settings.shortBreakMinutes = 5
    settings.longBreakMinutes = 15
    engine.applyDurations(from: settings)
    #expect(engine.focusDuration == 25 * 60)
    #expect(engine.shortBreakDuration == 5 * 60)
    #expect(engine.longBreakDuration == 15 * 60)
  }

  @Test func skipFocusStartsShortBreak() {
    let engine = SessionEngine()
    engine.start()
    engine.skip()
    guard case .running(let phase, _, _) = engine.state else {
      Issue.record("Expected running state")
      return
    }
    #expect(phase == .shortBreak)
  }

  @Test func skipBreakStartsFocus() {
    let engine = SessionEngine()
    engine.start()
    engine.skip()
    engine.skip()
    guard case .running(let phase, _, _) = engine.state else {
      Issue.record("Expected running state")
      return
    }
    #expect(phase == .focus)
  }

  @Test func timeRemainingDecreasesWithElapsedTime() {
    var currentTime = Date(timeIntervalSinceReferenceDate: 0)
    let engine = SessionEngine(focusDuration: 60, now: { currentTime })
    engine.start()
    currentTime = currentTime.addingTimeInterval(20)
    engine.pause()  // triggers timestamp refresh before freezing
    #expect(engine.timeRemaining == 40)
  }

  @Test func idleTimeRemainingIsFocusDuration() {
    let engine = SessionEngine(focusDuration: 1500)
    #expect(engine.timeRemaining == 1500)
  }

  @Test func stopResetsTimeRemaining() {
    let engine = SessionEngine(focusDuration: 1500)
    engine.start()
    engine.stop()
    #expect(engine.timeRemaining == 1500)
  }

  @Test func skipFromPausedMovesToPausedNextPhase() {
    let engine = SessionEngine()
    engine.start()
    engine.pause()
    engine.skip()
    guard case .paused(let phase, _) = engine.state else {
      Issue.record("Expected paused state")
      return
    }
    #expect(phase == .shortBreak)
  }

  @Test func skipFromPausedPreservesFullDuration() {
    var currentTime = Date(timeIntervalSinceReferenceDate: 0)
    let engine = SessionEngine(focusDuration: 60, shortBreakDuration: 300, now: { currentTime })
    engine.start()
    currentTime = currentTime.addingTimeInterval(20)  // 40s remaining in focus
    engine.pause()
    engine.skip()  // skip to short break — should start at full 300s, not leftover 40s
    guard case .paused(_, let remaining) = engine.state else {
      Issue.record("Expected paused state")
      return
    }
    #expect(remaining == 300)
  }

  @Test func isRunningWhileActive() {
    let engine = SessionEngine()
    engine.start()
    #expect(engine.isRunning == true)
  }

  @Test func isRunningFalseWhenPaused() {
    let engine = SessionEngine()
    engine.start()
    engine.pause()
    #expect(engine.isRunning == false)
  }

  @Test func isRunningFalseWhenIdle() {
    let engine = SessionEngine()
    #expect(engine.isRunning == false)
  }

  // MARK: - Guard / no-op behaviours

  @Test func startIsNoOpWhenRunning() {
    let engine = SessionEngine()
    engine.start()
    guard case .running(_, let startedAt, _) = engine.state else {
      Issue.record("Expected running state")
      return
    }
    engine.start()  // should be ignored
    guard case .running(_, let startedAtAfter, _) = engine.state else {
      Issue.record("Expected running state")
      return
    }
    #expect(startedAt == startedAtAfter)
  }

  @Test func pauseIsNoOpWhenIdle() {
    let engine = SessionEngine()
    engine.pause()
    #expect(engine.state == .idle)
  }

  @Test func resumeIsNoOpWhenRunning() {
    let engine = SessionEngine()
    engine.start()
    guard case .running(_, let startedAt, _) = engine.state else {
      Issue.record("Expected running state")
      return
    }
    engine.resume()  // should be ignored
    guard case .running(_, let startedAtAfter, _) = engine.state else {
      Issue.record("Expected running state")
      return
    }
    #expect(startedAt == startedAtAfter)
  }

  @Test func startIsNoOpWhenPaused() {
    let engine = SessionEngine()
    engine.start()
    engine.pause()
    engine.start()  // should be ignored
    guard case .paused = engine.state else {
      Issue.record("Expected paused state")
      return
    }
  }

  @Test func pauseIsNoOpWhenPaused() {
    var currentTime = Date(timeIntervalSinceReferenceDate: 0)
    let engine = SessionEngine(focusDuration: 60, now: { currentTime })
    engine.start()
    currentTime = currentTime.addingTimeInterval(10)
    engine.pause()
    currentTime = currentTime.addingTimeInterval(10)  // time passes while paused
    engine.pause()  // should be ignored — remaining should not change
    guard case .paused(_, let remaining) = engine.state else {
      Issue.record("Expected paused state")
      return
    }
    #expect(remaining == 50)
  }

  @Test func resumeIsNoOpWhenIdle() {
    let engine = SessionEngine()
    engine.resume()
    #expect(engine.state == .idle)
  }

  @Test func skipFromIdleSetsQueuedFocus() {
    let engine = SessionEngine()
    engine.skip()
    #expect(engine.state == .idle)
    #expect(engine.queuedPhase == .focus)
  }

  // MARK: - consumedFocusSeconds (D4 of design doc 0010)

  @Test func consumedFocusSecondsIsZeroWhenIdle() {
    let engine = SessionEngine()
    #expect(engine.consumedFocusSeconds == 0)
  }

  @Test func consumedFocusSecondsTracksElapsedTimeWhileRunning() {
    var currentTime = Date(timeIntervalSinceReferenceDate: 0)
    let engine = SessionEngine(focusDuration: 60, now: { currentTime })
    engine.start()
    currentTime = currentTime.addingTimeInterval(20)
    #expect(engine.consumedFocusSeconds == 20)
  }

  @Test func consumedFocusSecondsIsZeroDuringABreak() {
    var currentTime = Date(timeIntervalSinceReferenceDate: 0)
    let engine = SessionEngine(shortBreakDuration: 60, now: { currentTime })
    engine.start(phase: .shortBreak)
    currentTime = currentTime.addingTimeInterval(20)
    #expect(engine.consumedFocusSeconds == 0)
  }

  @Test func consumedFocusSecondsIsMonotonicAcrossPauseAndResume() {
    var currentTime = Date(timeIntervalSinceReferenceDate: 0)
    let engine = SessionEngine(focusDuration: 60, now: { currentTime })
    engine.start()
    currentTime = currentTime.addingTimeInterval(20)
    engine.pause()
    #expect(engine.consumedFocusSeconds == 20)

    // Time passes while paused — consumed time must not advance during the gap.
    currentTime = currentTime.addingTimeInterval(500)
    #expect(engine.consumedFocusSeconds == 20)

    engine.resume()
    #expect(engine.consumedFocusSeconds == 20)
    currentTime = currentTime.addingTimeInterval(10)
    #expect(engine.consumedFocusSeconds == 30)
  }

  // MARK: - began (D4 of design doc 0010)

  @Test func startEmitsBeganEvent() async {
    let engine = SessionEngine()
    engine.start()
    var iterator = engine.phaseEvents.makeAsyncIterator()
    guard case .began(let phase) = await iterator.next() else {
      Issue.record("Expected a began event")
      return
    }
    #expect(phase == .focus)
  }

  @Test func resumeDoesNotEmitBeganEvent() async {
    let engine = SessionEngine()
    engine.start()
    engine.pause()
    engine.resume()
    var iterator = engine.phaseEvents.makeAsyncIterator()
    guard case .began = await iterator.next() else {
      Issue.record("Expected the initial began event from start()")
      return
    }
    // No further event should be buffered — resume() does not emit began.
    engine.pause()  // sentinel: distinguishable no-op, buffers nothing either
    engine.stop()
    guard case .ended = await iterator.next() else {
      Issue.record("Expected stop()'s ended event next, not a spurious began from resume()")
      return
    }
  }

}
