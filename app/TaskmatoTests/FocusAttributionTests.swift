//
//  FocusAttributionTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

private func makeTask(providerID: ProviderID, nativeID: String, title: String) -> TaskItem {
  TaskItem(
    id: TaskRef(providerID: providerID, nativeID: nativeID),
    title: title,
    notes: nil,
    format: .plainText,
    priority: .none,
    dueDate: nil,
    scheduledDate: nil,
    startDate: nil,
    list: nil,
    section: nil,
    sourceURL: nil,
    completedAt: nil,
    createdAt: nil
  )
}

@Suite("FocusAttribution")
@MainActor
struct FocusAttributionTests {

  private let taskA = makeTask(providerID: "local", nativeID: "a", title: "Task A")
  private let taskB = makeTask(providerID: "local", nativeID: "b", title: "Task B")
  private let taskC = makeTask(providerID: "local", nativeID: "c", title: "Task C")

  // MARK: - Basic resolution (D1/D4 of design doc 0010)

  @Test func noTaskChangeYieldsOneSegment() {
    let attribution = FocusAttribution()
    attribution.begin(task: taskA)
    let segments = attribution.finish(consumedSeconds: 1_500)
    #expect(segments.count == 1)
    #expect(segments.first?.taskRef == taskA.id)
    #expect(segments.first?.taskTitle == taskA.title)
    #expect(segments.first?.seconds == 1_500)
  }

  @Test func completeThenResumeThenEndYieldsTwoSlicesSummingToDuration() {
    let attribution = FocusAttribution()
    attribution.begin(task: taskA)
    attribution.taskChanged(to: taskB, consumedSeconds: 600)
    let segments = attribution.finish(consumedSeconds: 1_500)
    #expect(segments.count == 2)
    #expect(segments[0].taskRef == taskA.id)
    #expect(segments[0].seconds == 600)
    #expect(segments[1].taskRef == taskB.id)
    #expect(segments[1].seconds == 900)
    #expect(segments.map(\.seconds).reduce(0, +) == 1_500)
  }

  @Test func threeTaskChainYieldsThreeSegments() {
    let attribution = FocusAttribution()
    attribution.begin(task: taskA)
    attribution.taskChanged(to: taskB, consumedSeconds: 300)
    attribution.taskChanged(to: taskC, consumedSeconds: 700)
    let segments = attribution.finish(consumedSeconds: 1_000)
    #expect(segments.count == 3)
    #expect(segments.map(\.seconds) == [300, 400, 300])
    #expect(segments.map { $0.taskRef } == [taskA.id, taskB.id, taskC.id])
  }

  @Test func untrackedFocusYieldsNilTaskRefSegment() {
    let attribution = FocusAttribution()
    attribution.begin(task: nil)
    let segments = attribution.finish(consumedSeconds: 300)
    #expect(segments.count == 1)
    #expect(segments.first?.taskRef == nil)
  }

  @Test func clearMidPhaseYieldsUntrackedTrailingSegment() {
    let attribution = FocusAttribution()
    attribution.begin(task: taskA)
    attribution.taskChanged(to: nil, consumedSeconds: 500)
    let segments = attribution.finish(consumedSeconds: 800)
    #expect(segments.count == 2)
    #expect(segments[0].taskRef == taskA.id)
    #expect(segments[1].taskRef == nil)
    #expect(segments[1].seconds == 300)
  }

  @Test func zeroSecondSlicesAreDropped() {
    let attribution = FocusAttribution()
    attribution.begin(task: taskA)
    attribution.taskChanged(to: taskB, consumedSeconds: 0)  // no time elapsed — no-op slice
    let segments = attribution.finish(consumedSeconds: 500)
    // The zero-length A slice is dropped; only the (now-current) B slice survives.
    #expect(segments.count == 1)
    #expect(segments.first?.taskRef == taskB.id)
    #expect(segments.first?.seconds == 500)
  }

  @Test func finishWithNoSecondsElapsedYieldsNoSegments() {
    let attribution = FocusAttribution()
    attribution.begin(task: taskA)
    let segments = attribution.finish(consumedSeconds: 0)
    #expect(segments.isEmpty)
  }

  // MARK: - Guard: only live while begun (D4)

  @Test func taskChangedBeforeBeginIsNoOp() {
    let attribution = FocusAttribution()
    attribution.taskChanged(to: taskA, consumedSeconds: 100)
    #expect(attribution.finish(consumedSeconds: 100).isEmpty)
  }

  @Test func taskChangedAfterFinishIsNoOp() {
    let attribution = FocusAttribution()
    attribution.begin(task: taskA)
    _ = attribution.finish(consumedSeconds: 100)
    attribution.taskChanged(to: taskB, consumedSeconds: 0)
    attribution.begin(task: taskC)
    let segments = attribution.finish(consumedSeconds: 50)
    #expect(segments.count == 1)
    #expect(segments.first?.taskRef == taskC.id)
  }

  @Test func finishClearsStateForTheNextPhase() {
    let attribution = FocusAttribution()
    attribution.begin(task: taskA)
    _ = attribution.finish(consumedSeconds: 300)
    #expect(attribution.isLive == false)
    attribution.begin(task: taskB)
    let segments = attribution.finish(consumedSeconds: 200)
    #expect(segments.count == 1)
    #expect(segments.first?.taskRef == taskB.id)
    #expect(segments.first?.seconds == 200)
  }

  // MARK: - onSliceClosed (drives the D7 draft upsert)

  @Test func onSliceClosedFiresOnlyForNonZeroSlices() {
    let attribution = FocusAttribution()
    var closed: [FocusSegment] = []
    attribution.onSliceClosed = { closed.append($0) }
    attribution.begin(task: taskA)
    attribution.taskChanged(to: taskB, consumedSeconds: 0)  // zero-length — no callback
    attribution.taskChanged(to: taskC, consumedSeconds: 400)  // B's slice closes
    #expect(closed.count == 1)
    #expect(closed.first?.taskRef == taskB.id)
    #expect(closed.first?.seconds == 400)
  }

  @Test func onSliceClosedDoesNotFireAtFinish() {
    let attribution = FocusAttribution()
    var closedCount = 0
    attribution.onSliceClosed = { _ in closedCount += 1 }
    attribution.begin(task: taskA)
    _ = attribution.finish(consumedSeconds: 500)
    // finish() resolves the trailing slice itself; onSliceClosed is only for mid-phase closes.
    #expect(closedCount == 0)
  }

  // MARK: - Completion-instant race (D4 concurrency note)

  @Test func staleTaskChangeAtCompletionInstantDoesNotCorruptTheLog() {
    let attribution = FocusAttribution()
    attribution.begin(task: taskA)
    attribution.taskChanged(to: taskB, consumedSeconds: 100)
    // Simulate the race: the engine has already reset to idle (consumedFocusSeconds reads 0
    // again) but `PhaseOrchestrator` hasn't yet drained the `.ended` event and called
    // `finish()`. A task change firing in that window must not steal the whole phase.
    attribution.taskChanged(to: taskC, consumedSeconds: 0)
    let segments = attribution.finish(consumedSeconds: 150)
    #expect(segments.count == 2)
    #expect(segments[0].taskRef == taskA.id)
    #expect(segments[0].seconds == 100)
    #expect(segments[1].taskRef == taskB.id)
    #expect(segments[1].seconds == 50)
  }

  @Test func staleTaskChangeDoesNotLeakIntoTheNextPhase() {
    let attribution = FocusAttribution()
    attribution.begin(task: taskA)
    _ = attribution.finish(consumedSeconds: 200)
    // A stale change arriving after finish() (isLive already false) must not resurrect the log.
    attribution.taskChanged(to: taskB, consumedSeconds: 0)
    attribution.begin(task: taskC)
    let segments = attribution.finish(consumedSeconds: 100)
    #expect(segments.count == 1)
    #expect(segments.first?.taskRef == taskC.id)
    #expect(segments.first?.seconds == 100)
  }

  // MARK: - Provider cosmetics snapshot (ADR-0010, D4)

  @Test func finishSnapshotsCosmeticsWhenResolverMatches() {
    let attribution = FocusAttribution(cosmetics: { _ in ("Local", .green) })
    attribution.begin(task: taskA)
    let segments = attribution.finish(consumedSeconds: 300)
    #expect(segments.first?.providerLabel == "Local")
    #expect(segments.first?.providerTint == .green)
  }

  @Test func taskChangedSnapshotsCosmeticsOnTheClosedSlice() {
    let attribution = FocusAttribution(cosmetics: { _ in ("Local", .green) })
    var closed: [FocusSegment] = []
    attribution.onSliceClosed = { closed.append($0) }
    attribution.begin(task: taskA)
    attribution.taskChanged(to: taskB, consumedSeconds: 400)
    #expect(closed.first?.providerLabel == "Local")
    #expect(closed.first?.providerTint == .green)
  }

  @Test func untrackedFocusYieldsNilCosmetics() {
    let attribution = FocusAttribution(cosmetics: { _ in ("Local", .green) })
    attribution.begin(task: nil)
    let segments = attribution.finish(consumedSeconds: 300)
    #expect(segments.first?.providerLabel == nil)
    #expect(segments.first?.providerTint == nil)
  }

  @Test func resolverReturningNilYieldsNilCosmetics() {
    let attribution = FocusAttribution(cosmetics: { _ in nil })
    attribution.begin(task: taskA)
    let segments = attribution.finish(consumedSeconds: 300)
    #expect(segments.first?.providerLabel == nil)
    #expect(segments.first?.providerTint == nil)
  }

  @Test func defaultInitYieldsNilCosmetics() {
    let attribution = FocusAttribution()
    attribution.begin(task: taskA)
    let segments = attribution.finish(consumedSeconds: 300)
    #expect(segments.first?.providerLabel == nil)
    #expect(segments.first?.providerTint == nil)
  }
}
