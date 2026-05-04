//
//  SessionEngineTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

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

}
