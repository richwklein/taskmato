//
//  NextUpPresenterTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

private func makeItem(providerID: ProviderID, nativeID: String, title: String) -> TaskItem {
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
    sourceURL: nil
  )
}

/// Groups an isolated ``NextUpPresenter`` with the collaborators tests mutate directly.
@MainActor
private struct Subjects {
  let presenter: NextUpPresenter
  let selectionStore: TaskSelectionStore
  let settings: AppSettings
  let engine: SessionEngine

  /// Leaves the engine somewhere other than idle-with-focus-next, where the countdown is not
  /// already showing the staged length and the readout is therefore allowed to render.
  func queueABreak() {
    engine.enqueuePhase(.shortBreak)
  }
}

@Suite("NextUpPresenter")
@MainActor
struct NextUpPresenterTests {

  /// Builds an isolated selection store, settings, and the presenter under test.
  private func makeSubjects() -> Subjects {
    let settingsStore = SettingsStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
    let settings = AppSettings(store: settingsStore)
    let selectionStore = TaskSelectionStore(store: settingsStore)
    let engine = SessionEngine()
    let timerPresenter = TimerPresenter(engine: engine, settings: settings)
    let presenter = NextUpPresenter(
      presenter: timerPresenter, selectionStore: selectionStore, settings: settings)
    return Subjects(
      presenter: presenter, selectionStore: selectionStore, settings: settings, engine: engine)
  }

  // MARK: - showsNextUp tracks stagedTask

  @Test func showsNextUpIsFalseWithNothingStaged() {
    let subjects = makeSubjects()
    #expect(subjects.presenter.showsNextUp == false)
  }

  @Test func showsNextUpIsTrueOnceATaskIsStaged() {
    let subjects = makeSubjects()
    subjects.queueABreak()
    subjects.selectionStore.stage(makeItem(providerID: "alpha", nativeID: "1", title: "Staged"))
    #expect(subjects.presenter.showsNextUp)
  }

  @Test func showsNextUpReturnsFalseAfterTheStagedTaskIsCleared() {
    let subjects = makeSubjects()
    subjects.queueABreak()
    subjects.selectionStore.stage(makeItem(providerID: "alpha", nativeID: "1", title: "Staged"))
    subjects.selectionStore.clearStagedTask()
    #expect(subjects.presenter.showsNextUp == false)
  }

  @Test func showsNextUpReturnsFalseAfterTheStagedTaskIsPromoted() {
    let subjects = makeSubjects()
    subjects.queueABreak()
    subjects.selectionStore.stage(makeItem(providerID: "alpha", nativeID: "1", title: "Staged"))
    subjects.selectionStore.applyStagedTask()
    #expect(subjects.presenter.showsNextUp == false)
  }

  /// Staging survives `stop()` (D-e), so a staged task can outlive the session and leave the
  /// engine idle with focus next — where the countdown already reads the staged length and
  /// design doc 0009 resolved the line as "no line".
  @Test func showsNextUpIsFalseWhileIdleWithFocusNextEvenWithATaskStaged() {
    let subjects = makeSubjects()
    subjects.selectionStore.stage(makeItem(providerID: "alpha", nativeID: "1", title: "Staged"))
    #expect(subjects.presenter.stagedTask != nil)
    #expect(subjects.presenter.showsNextUp == false)
  }

  @Test func showsNextUpIsTrueWhileAFocusPhaseIsRunning() {
    let subjects = makeSubjects()
    subjects.engine.start(phase: .focus)
    subjects.selectionStore.stage(makeItem(providerID: "alpha", nativeID: "1", title: "Staged"))
    #expect(subjects.presenter.showsNextUp)
  }

  @Test func stagedTaskMirrorsTheSelectionStoresStagedTask() {
    let subjects = makeSubjects()
    let staged = makeItem(providerID: "alpha", nativeID: "1", title: "Staged")
    subjects.selectionStore.stage(staged)
    #expect(subjects.presenter.stagedTask == staged)
  }

  // MARK: - nextFocusMinutes reflects settings.focusMinutes live

  @Test func nextFocusMinutesReflectsTheCurrentFocusMinutes() {
    let subjects = makeSubjects()
    subjects.settings.focusMinutes = 45
    #expect(subjects.presenter.nextFocusMinutes == 45)
  }

  @Test func nextFocusMinutesTracksALiveChangeAfterStaging() {
    let subjects = makeSubjects()
    subjects.selectionStore.stage(makeItem(providerID: "alpha", nativeID: "1", title: "Staged"))
    subjects.settings.focusMinutes = 15
    #expect(subjects.presenter.nextFocusMinutes == 15)
    subjects.settings.focusMinutes = 60
    #expect(subjects.presenter.nextFocusMinutes == 60)
  }

  @Test func nextFocusMinutesTracksAFocusPresetsResnap() {
    // AppSettings.setFocusPresets(_:) re-snaps focusMinutes to the nearest remaining preset when
    // the edit drops the current value — the readout must follow, not a value cached at stage time.
    let subjects = makeSubjects()
    subjects.settings.focusMinutes = 25
    subjects.selectionStore.stage(makeItem(providerID: "alpha", nativeID: "1", title: "Staged"))
    subjects.settings.setFocusPresets([15, 45, 60])
    #expect(subjects.settings.focusMinutes != 25)
    #expect(subjects.presenter.nextFocusMinutes == subjects.settings.focusMinutes)
  }
}
