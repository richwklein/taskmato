//
//  SessionEngineCycleTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

struct SessionEngineCycleTests {

  // MARK: - completedFocusCount initial state

  @Test func completedFocusCountStartsAtZero() {
    let engine = SessionEngine()
    #expect(engine.completedFocusCount == 0)
  }

  // MARK: - completedFocusCount increments

  @Test func completedFocusCountIncrementsOnNaturalFocusCompletion() {
    var currentTime = Date(timeIntervalSinceReferenceDate: 0)
    let engine = SessionEngine(focusDuration: 60, now: { currentTime })
    engine.start()
    currentTime = currentTime.addingTimeInterval(60)
    engine.pause()
    #expect(engine.completedFocusCount == 1)
  }

  @Test func completedFocusCountAccumulatesAcrossMultipleSessions() {
    var currentTime = Date(timeIntervalSinceReferenceDate: 0)
    let engine = SessionEngine(focusDuration: 60, now: { currentTime })
    for _ in 0..<3 {
      engine.start()
      currentTime = currentTime.addingTimeInterval(60)
      engine.pause()
    }
    #expect(engine.completedFocusCount == 3)
  }

  @Test func completedFocusCountDoesNotIncrementOnManualStop() {
    let engine = SessionEngine()
    engine.start()
    engine.stop()
    #expect(engine.completedFocusCount == 0)
  }

  @Test func completedFocusCountDoesNotIncrementOnSkip() {
    let engine = SessionEngine()
    engine.start()
    engine.skip()
    #expect(engine.completedFocusCount == 0)
  }

  @Test func completedFocusCountDoesNotIncrementOnBreakCompletion() {
    var currentTime = Date(timeIntervalSinceReferenceDate: 0)
    let engine = SessionEngine(shortBreakDuration: 60, now: { currentTime })
    engine.start(phase: .shortBreak)
    currentTime = currentTime.addingTimeInterval(60)
    engine.pause()
    #expect(engine.completedFocusCount == 0)
  }

  // MARK: - completedFocusCount resets

  @Test func completedFocusCountResetsOnNaturalLongBreakCompletion() {
    var currentTime = Date(timeIntervalSinceReferenceDate: 0)
    let engine = SessionEngine(focusDuration: 60, longBreakDuration: 60, now: { currentTime })
    engine.start()
    currentTime = currentTime.addingTimeInterval(60)
    engine.pause()
    #expect(engine.completedFocusCount == 1)

    engine.start(phase: .longBreak)
    currentTime = currentTime.addingTimeInterval(60)
    engine.pause()
    #expect(engine.completedFocusCount == 0)
  }

  @Test func completedFocusCountDoesNotResetOnManualLongBreakStop() {
    var currentTime = Date(timeIntervalSinceReferenceDate: 0)
    let engine = SessionEngine(focusDuration: 60, now: { currentTime })
    engine.start()
    currentTime = currentTime.addingTimeInterval(60)
    engine.pause()
    #expect(engine.completedFocusCount == 1)

    engine.start(phase: .longBreak)
    engine.stop()
    #expect(engine.completedFocusCount == 1)
  }

  @Test func completedFocusCountDoesNotResetOnShortBreakCompletion() {
    var currentTime = Date(timeIntervalSinceReferenceDate: 0)
    let engine = SessionEngine(
      focusDuration: 60, shortBreakDuration: 60, now: { currentTime })
    engine.start()
    currentTime = currentTime.addingTimeInterval(60)
    engine.pause()

    engine.start(phase: .shortBreak)
    currentTime = currentTime.addingTimeInterval(60)
    engine.pause()
    #expect(engine.completedFocusCount == 1)
  }

  // MARK: - nextBreakPhase

  @Test func nextBreakPhaseIsShortBreakAtStart() {
    let engine = SessionEngine()
    #expect(engine.nextBreakPhase(longBreakAfter: 4) == .shortBreak)
  }

  @Test func nextBreakPhaseIsShortBreakBeforeThreshold() {
    var currentTime = Date(timeIntervalSinceReferenceDate: 0)
    let engine = SessionEngine(focusDuration: 60, now: { currentTime })
    for _ in 0..<3 {
      engine.start()
      currentTime = currentTime.addingTimeInterval(60)
      engine.pause()
    }
    #expect(engine.nextBreakPhase(longBreakAfter: 4) == .shortBreak)
  }

  @Test func nextBreakPhaseIsLongBreakAtThreshold() {
    var currentTime = Date(timeIntervalSinceReferenceDate: 0)
    let engine = SessionEngine(focusDuration: 60, now: { currentTime })
    for _ in 0..<4 {
      engine.start()
      currentTime = currentTime.addingTimeInterval(60)
      engine.pause()
    }
    #expect(engine.nextBreakPhase(longBreakAfter: 4) == .longBreak)
  }

  @Test func nextBreakPhaseIsShortBreakAfterThreshold() {
    var currentTime = Date(timeIntervalSinceReferenceDate: 0)
    let engine = SessionEngine(focusDuration: 60, now: { currentTime })
    for _ in 0..<5 {
      engine.start()
      currentTime = currentTime.addingTimeInterval(60)
      engine.pause()
    }
    #expect(engine.nextBreakPhase(longBreakAfter: 4) == .shortBreak)
  }

  @Test func nextBreakPhaseResetsAfterLongBreak() {
    var currentTime = Date(timeIntervalSinceReferenceDate: 0)
    let engine = SessionEngine(
      focusDuration: 60, longBreakDuration: 60, now: { currentTime })
    for _ in 0..<4 {
      engine.start()
      currentTime = currentTime.addingTimeInterval(60)
      engine.pause()
    }
    #expect(engine.nextBreakPhase(longBreakAfter: 4) == .longBreak)

    engine.start(phase: .longBreak)
    currentTime = currentTime.addingTimeInterval(60)
    engine.pause()
    #expect(engine.nextBreakPhase(longBreakAfter: 4) == .shortBreak)
  }

  @Test func nextBreakPhaseRespectsCustomInterval() {
    var currentTime = Date(timeIntervalSinceReferenceDate: 0)
    let engine = SessionEngine(focusDuration: 60, now: { currentTime })
    for _ in 0..<2 {
      engine.start()
      currentTime = currentTime.addingTimeInterval(60)
      engine.pause()
    }
    #expect(engine.nextBreakPhase(longBreakAfter: 2) == .longBreak)
  }
}
