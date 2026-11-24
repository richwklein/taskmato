//
//  TimerPresenterContinuationTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

/// Covers `pendingContinuationRemaining`: the remainder a complete, swap or clear paused for a
/// handoff, offered by the task context menu's leftover submenu.
@MainActor
struct TimerPresenterContinuationTests {

  private func makeStore() -> ActiveTaskStore {
    let store = ActiveTaskStore(
      store: SettingsStore(defaults: UserDefaults(suiteName: UUID().uuidString)!))
    store.track(
      TaskItem(
        id: TaskRef(providerID: "stub", nativeID: UUID().uuidString), title: "Write the spec",
        notes: nil, format: .plainText, priority: .none, dueDate: nil, scheduledDate: nil,
        startDate: nil, list: nil, section: nil, sourceURL: nil, completedAt: nil,
        createdAt: Date()))
    return store
  }

  private func makePresenter(_ store: ActiveTaskStore) -> TimerPresenter {
    let settings = AppSettings(
      store: SettingsStore(defaults: UserDefaults(suiteName: UUID().uuidString)!))
    return TimerPresenter(engine: SessionEngine(), settings: settings, activeTaskStore: store)
  }

  @Test func isSetForPausedFocusWithTheFlag() {
    let store = makeStore()
    let presenter = makePresenter(store)
    presenter.start()
    presenter.pause()
    store.markPendingContinuation()
    #expect(presenter.pendingContinuationRemaining != nil)
    #expect(presenter.pendingContinuationLabel == presenter.label)
  }

  @Test func isNilForAManualPause() {
    let presenter = makePresenter(makeStore())
    presenter.start()
    presenter.pause()
    #expect(presenter.pendingContinuationRemaining == nil)
    #expect(presenter.pendingContinuationLabel == nil)
  }

  @Test func isNilWhenIdleEvenWithTheFlag() {
    let store = makeStore()
    let presenter = makePresenter(store)
    store.markPendingContinuation()
    #expect(presenter.pendingContinuationRemaining == nil)
  }

  @Test func isNilForAPausedBreak() {
    let store = makeStore()
    let presenter = makePresenter(store)
    presenter.start()
    presenter.skip()
    presenter.pause()
    store.markPendingContinuation()
    #expect(presenter.isPaused)
    #expect(presenter.pendingContinuationRemaining == nil)
  }

  @Test func clearsWhenTheTimerStops() {
    let store = makeStore()
    let presenter = makePresenter(store)
    presenter.start()
    presenter.pause()
    store.markPendingContinuation()
    presenter.stop()
    #expect(presenter.pendingContinuationRemaining == nil)
  }

  @Test func clearsWhenTheTimerResumes() {
    let store = makeStore()
    let presenter = makePresenter(store)
    presenter.start()
    presenter.pause()
    store.markPendingContinuation()
    presenter.resume()
    #expect(presenter.pendingContinuationRemaining == nil)
  }
}
