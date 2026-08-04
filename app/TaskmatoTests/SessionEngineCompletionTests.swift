//
//  SessionEngineCompletionTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

/// Advances through `stream`, skipping any `.began` events, to the next `.ended` event —
/// `start()` and `skip()` now also buffer `.began` (D4 of design doc 0010), which most of
/// these completion-focused tests are not asserting against. Safe to call more than once on
/// the same stream: each call draws a fresh iterator over the stream's shared buffer, so
/// sequential calls continue from where the previous one left off.
@MainActor
private func nextEnded(in stream: AsyncStream<PhaseEvent>) async -> PhaseEvent? {
  for await event in stream {
    if case .ended = event { return event }
  }
  return nil
}

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
    guard case .ended(let phase, _, _, _) = await nextEnded(in: engine.phaseEvents) else {
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
    guard case .ended(_, let start, let end, _) = await nextEnded(in: engine.phaseEvents) else {
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
    guard case .ended(_, _, _, let wasCompleted) = await nextEnded(in: engine.phaseEvents) else {
      Issue.record("Expected a phase-end event")
      return
    }
    #expect(wasCompleted == true)
  }

  @Test func manualStopFiresEventWithWasCompletedFalse() async {
    let engine = SessionEngine()
    engine.start()
    engine.stop()
    guard case .ended(_, _, _, let wasCompleted) = await nextEnded(in: engine.phaseEvents) else {
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
    let event = await nextEnded(in: engine.phaseEvents)
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

    guard case .ended(let phase, _, _, let wasCompleted) = await nextEnded(in: engine.phaseEvents)
    else {
      Issue.record("Expected exactly one phase-end event")
      return
    }
    #expect(phase == .focus)
    #expect(wasCompleted == true)
  }

  @Test func skipFocusFiresPartialEndedEventBeforeTheNextPhaseBegins() async {
    // D7 of design doc 0010: skipping a focus phase now emits a partial `.ended(.focus,
    // wasCompleted: false)` so its invested time is credited, ahead of the next phase's began.
    var currentTime = Date(timeIntervalSinceReferenceDate: 0)
    let engine = SessionEngine(focusDuration: 60, now: { currentTime })
    engine.start()
    currentTime = currentTime.addingTimeInterval(20)
    engine.skip()

    var iterator = engine.phaseEvents.makeAsyncIterator()
    guard case .began(let firstBegan) = await iterator.next() else {
      Issue.record("Expected the initial began(.focus) event")
      return
    }
    #expect(firstBegan == .focus)

    guard case .ended(let phase, _, _, let wasCompleted) = await iterator.next() else {
      Issue.record("Expected a partial focus ended event from skip")
      return
    }
    #expect(phase == .focus)
    #expect(wasCompleted == false)

    guard case .began(let nextBegan) = await iterator.next() else {
      Issue.record("Expected the short-break began event")
      return
    }
    #expect(nextBegan == .shortBreak)
  }

  @Test func skipBreakDoesNotFirePartialEndedEvent() async {
    // Skipping a break is unchanged — no synthesized partial `.ended` for the break itself.
    let engine = SessionEngine(focusDuration: 60, shortBreakDuration: 60)
    engine.start()
    engine.skip()  // focus -> shortBreak: partial ended(.focus) + began(.shortBreak)
    engine.skip()  // shortBreak -> focus: only began(.focus), no ended for the break

    var iterator = engine.phaseEvents.makeAsyncIterator()
    guard case .began(let firstBegan) = await iterator.next() else {
      Issue.record("Expected began(.focus)")
      return
    }
    #expect(firstBegan == .focus)

    guard case .ended(let endedPhase, _, _, let wasCompleted) = await iterator.next() else {
      Issue.record("Expected the partial focus ended event")
      return
    }
    #expect(endedPhase == .focus)
    #expect(wasCompleted == false)

    guard case .began(let secondBegan) = await iterator.next() else {
      Issue.record("Expected began(.shortBreak)")
      return
    }
    #expect(secondBegan == .shortBreak)

    guard case .began(let thirdBegan) = await iterator.next() else {
      Issue.record("Expected began(.focus) again, with no ended event for the break")
      return
    }
    #expect(thirdBegan == .focus)
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

    guard
      case .ended(let firstPhase, _, _, let firstCompleted) = await nextEnded(
        in: engine.phaseEvents)
    else {
      Issue.record("Expected the natural-completion event")
      return
    }
    #expect(firstPhase == .focus)
    #expect(firstCompleted == true)

    guard
      case .ended(let secondPhase, _, _, let secondCompleted) = await nextEnded(
        in: engine.phaseEvents)
    else {
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
