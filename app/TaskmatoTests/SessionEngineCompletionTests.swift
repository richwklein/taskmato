//
//  SessionEngineCompletionTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

@MainActor
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

  @Test func phaseCompletionFiresEvent() async {
    var currentTime = Date(timeIntervalSinceReferenceDate: 0)
    let engine = SessionEngine(focusDuration: 60, now: { currentTime })
    engine.start()
    currentTime = currentTime.addingTimeInterval(60)
    engine.pause()
    var iterator = engine.phaseEvents.makeAsyncIterator()
    guard case .ended(let phase, _, _, _) = await iterator.next() else {
      Issue.record("Expected a phase-end event")
      return
    }
    #expect(phase == .focus)
  }

  @Test func phaseCompletionEventCarriesCorrectTimes() async {
    let startTime = Date(timeIntervalSinceReferenceDate: 1000)
    var currentTime = startTime
    let engine = SessionEngine(focusDuration: 60, now: { currentTime })
    engine.start()
    currentTime = currentTime.addingTimeInterval(60)
    engine.pause()
    var iterator = engine.phaseEvents.makeAsyncIterator()
    guard case .ended(_, let start, let end, _) = await iterator.next() else {
      Issue.record("Expected a phase-end event")
      return
    }
    #expect(start == startTime)
    #expect(end == startTime.addingTimeInterval(60))
  }

  @Test func naturalCompletionMarksWasCompletedTrue() async {
    var currentTime = Date(timeIntervalSinceReferenceDate: 0)
    let engine = SessionEngine(focusDuration: 60, now: { currentTime })
    engine.start()
    currentTime = currentTime.addingTimeInterval(60)
    engine.pause()
    var iterator = engine.phaseEvents.makeAsyncIterator()
    guard case .ended(_, _, _, let wasCompleted) = await iterator.next() else {
      Issue.record("Expected a phase-end event")
      return
    }
    #expect(wasCompleted == true)
  }

  @Test func manualStopFiresEventWithWasCompletedFalse() async {
    let engine = SessionEngine()
    engine.start()
    engine.stop()
    var iterator = engine.phaseEvents.makeAsyncIterator()
    guard case .ended(_, _, _, let wasCompleted) = await iterator.next() else {
      Issue.record("Expected a phase-end event")
      return
    }
    #expect(wasCompleted == false)
  }

  @Test func manualStopFromPausedFiresEvent() async {
    let engine = SessionEngine()
    engine.start()
    engine.pause()
    engine.stop()
    var iterator = engine.phaseEvents.makeAsyncIterator()
    let event = await iterator.next()
    #expect(event != nil)
  }

  @Test func stopFromIdleDoesNotFireEvent() async {
    var currentTime = Date(timeIntervalSinceReferenceDate: 0)
    let engine = SessionEngine(focusDuration: 60, now: { currentTime })
    engine.stop()  // idle: must not buffer an event

    // Drive a real completion afterward as a sentinel: if the idle stop had wrongly
    // buffered something, this would not be the first event received.
    engine.start()
    currentTime = currentTime.addingTimeInterval(60)
    engine.pause()

    var iterator = engine.phaseEvents.makeAsyncIterator()
    guard case .ended(let phase, _, _, let wasCompleted) = await iterator.next() else {
      Issue.record("Expected exactly one phase-end event")
      return
    }
    #expect(phase == .focus)
    #expect(wasCompleted == true)
  }

  @Test func skipDoesNotFireEvent() async {
    var currentTime = Date(timeIntervalSinceReferenceDate: 0)
    let engine = SessionEngine(
      focusDuration: 60, shortBreakDuration: 60, now: { currentTime })
    engine.start()
    engine.skip()  // must not buffer an event

    // Drive the (now short-break) phase to natural completion as a sentinel: if skip()
    // had wrongly buffered a `.focus` event, this would not be the first event received.
    currentTime = currentTime.addingTimeInterval(60)
    engine.pause()

    var iterator = engine.phaseEvents.makeAsyncIterator()
    guard case .ended(let phase, _, _, let wasCompleted) = await iterator.next() else {
      Issue.record("Expected exactly one phase-end event")
      return
    }
    #expect(phase == .shortBreak)
    #expect(wasCompleted == true)
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

  // MARK: - Stop-at-completion double-emit guard

  @Test func stopExactlyAtCompletionEmitsSingleCompletedEvent() async {
    var currentTime = Date(timeIntervalSinceReferenceDate: 0)
    let engine = SessionEngine(
      focusDuration: 60, shortBreakDuration: 60, now: { currentTime })
    engine.start()
    currentTime = currentTime.addingTimeInterval(60)  // lands exactly at completion
    engine.stop()

    // Without the guard, `stop()` would additionally yield a stale
    // `.ended(phase: .focus, wasCompleted: false)` right after the natural completion.
    // Drive a second, distinguishable completion as a sentinel: if the duplicate were
    // present, it — not this sentinel — would be the second event received.
    engine.start(phase: .shortBreak)
    currentTime = currentTime.addingTimeInterval(60)
    engine.pause()

    var iterator = engine.phaseEvents.makeAsyncIterator()
    guard case .ended(let firstPhase, _, _, let firstCompleted) = await iterator.next() else {
      Issue.record("Expected the natural-completion event")
      return
    }
    #expect(firstPhase == .focus)
    #expect(firstCompleted == true)

    guard case .ended(let secondPhase, _, _, let secondCompleted) = await iterator.next() else {
      Issue.record("Expected the sentinel phase-end event")
      return
    }
    #expect(secondPhase == .shortBreak)
    #expect(secondCompleted == true)
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
