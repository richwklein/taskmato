//
//  SessionEngineCompletionTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

struct SessionEngineCompletionTests {

  // MARK: - Phase completion

  @Test func phaseCompletionTransitionsToIdle() {
    var currentTime = Date(timeIntervalSinceReferenceDate: 0)
    let engine = SessionEngine(focusDuration: 60, now: { currentTime })
    engine.start()
    currentTime = currentTime.addingTimeInterval(60)
    engine.pause()  // triggers refreshTimeRemaining, which detects completion
    #expect(engine.state == .idle)
  }

  @Test func phaseCompletionResetsTimeRemaining() {
    var currentTime = Date(timeIntervalSinceReferenceDate: 0)
    let engine = SessionEngine(focusDuration: 60, now: { currentTime })
    engine.start()
    currentTime = currentTime.addingTimeInterval(60)
    engine.pause()
    #expect(engine.timeRemaining == 60)
  }

  @Test func phaseCompletionFiresCallback() {
    var currentTime = Date(timeIntervalSinceReferenceDate: 0)
    let engine = SessionEngine(focusDuration: 60, now: { currentTime })
    var firedPhase: SessionPhase?
    engine.onPhaseEnded = { phase, _, _, _ in firedPhase = phase }
    engine.start()
    currentTime = currentTime.addingTimeInterval(60)
    engine.pause()
    #expect(firedPhase == .focus)
  }

  @Test func phaseCompletionCallbackReceivesCorrectTimes() {
    let startTime = Date(timeIntervalSinceReferenceDate: 1000)
    var currentTime = startTime
    let engine = SessionEngine(focusDuration: 60, now: { currentTime })
    var capturedStart: Date?
    var capturedEnd: Date?
    engine.onPhaseEnded = { _, start, end, _ in
      capturedStart = start
      capturedEnd = end
    }
    engine.start()
    currentTime = currentTime.addingTimeInterval(60)
    engine.pause()
    #expect(capturedStart == startTime)
    #expect(capturedEnd == startTime.addingTimeInterval(60))
  }

  @Test func naturalCompletionMarksWasCompletedTrue() {
    var currentTime = Date(timeIntervalSinceReferenceDate: 0)
    let engine = SessionEngine(focusDuration: 60, now: { currentTime })
    var wasCompleted: Bool?
    engine.onPhaseEnded = { _, _, _, completed in wasCompleted = completed }
    engine.start()
    currentTime = currentTime.addingTimeInterval(60)
    engine.pause()
    #expect(wasCompleted == true)
  }

  @Test func manualStopFiresCallbackWithWasCompletedFalse() {
    let engine = SessionEngine()
    var wasCompleted: Bool?
    engine.onPhaseEnded = { _, _, _, completed in wasCompleted = completed }
    engine.start()
    engine.stop()
    #expect(wasCompleted == false)
  }

  @Test func manualStopFromPausedFiresCallback() {
    let engine = SessionEngine()
    var fired = false
    engine.onPhaseEnded = { _, _, _, _ in fired = true }
    engine.start()
    engine.pause()
    engine.stop()
    #expect(fired)
  }

  @Test func stopFromIdleDoesNotFireCallback() {
    let engine = SessionEngine()
    var fired = false
    engine.onPhaseEnded = { _, _, _, _ in fired = true }
    engine.stop()
    #expect(!fired)
  }

  @Test func skipDoesNotFireCallback() {
    let engine = SessionEngine()
    var fired = false
    engine.onPhaseEnded = { _, _, _, _ in fired = true }
    engine.start()
    engine.skip()
    #expect(!fired)
  }

  @Test func skipUsesProvidedBreakPhase() {
    let engine = SessionEngine()
    engine.start()
    engine.skip(nextBreak: .longBreak)
    guard case .running(let phase, _, _) = engine.state else {
      Issue.record("Expected running state")
      return
    }
    #expect(phase == .longBreak)
  }

  // MARK: - enqueuePhase

  @Test func enqueuePhaseSetQueuedPhaseWhenIdle() {
    let engine = SessionEngine()
    engine.enqueuePhase(.shortBreak)
    #expect(engine.queuedPhase == .shortBreak)
    #expect(engine.state == .idle)
  }

  @Test func enqueuePhaseIsNoOpWhenRunning() {
    let engine = SessionEngine()
    engine.start()
    engine.enqueuePhase(.shortBreak)
    #expect(engine.queuedPhase == nil)
  }

  @Test func enqueuePhaseIsNoOpWhenPaused() {
    let engine = SessionEngine()
    engine.start()
    engine.pause()
    engine.enqueuePhase(.shortBreak)
    #expect(engine.queuedPhase == nil)
  }

  @Test func startClearsQueuedPhase() {
    let engine = SessionEngine()
    engine.enqueuePhase(.shortBreak)
    #expect(engine.queuedPhase != nil)
    engine.start(phase: engine.queuedPhase ?? .focus)
    #expect(engine.queuedPhase == nil)
  }

  @Test func stopClearsQueuedPhase() {
    let engine = SessionEngine()
    engine.enqueuePhase(.shortBreak)
    #expect(engine.queuedPhase != nil)
    engine.start()
    engine.stop()
    #expect(engine.queuedPhase == nil)
  }
}
