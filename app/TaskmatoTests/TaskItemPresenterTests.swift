//
//  TaskItemPresenterTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

@Suite("TaskItemPresenter")
struct TaskItemPresenterTests {

  /// Builds a task with only the fields the presenter reads, defaulting the rest.
  private func makeTask(
    priority: TaskPriority = .none,
    dueDate: Date? = nil,
    completedAt: Date? = nil
  ) -> TaskItem {
    TaskItem(
      id: TaskRef(providerID: "local", nativeID: "1"),
      title: "Sample task",
      notes: nil,
      format: .plainText,
      priority: priority,
      dueDate: dueDate,
      scheduledDate: nil,
      startDate: nil,
      list: nil,
      section: nil,
      sourceURL: nil,
      completedAt: completedAt,
      createdAt: nil
    )
  }

  // MARK: - Kind

  @Test func activeKindIsNotCompleted() {
    let presenter = TaskItemPresenter(task: makeTask(), kind: .active(onComplete: {}))
    #expect(!presenter.isCompleted)
    #expect(!presenter.showsRestore)
  }

  @Test func completedKindIsCompleted() {
    let presenter = TaskItemPresenter(
      task: makeTask(), kind: .completed(onRestore: {}, onDelete: nil))
    #expect(presenter.isCompleted)
    #expect(presenter.showsRestore)
  }

  // MARK: - Action affordances

  @Test func activeExposesCompletionToggleWhenCompletable() {
    var completed = false
    let presenter = TaskItemPresenter(
      task: makeTask(), kind: .active(onComplete: { completed = true }))
    #expect(presenter.showsCompletionToggle)
    #expect(presenter.onRestore == nil)
    #expect(presenter.onDelete == nil)
    presenter.onComplete?()
    #expect(completed)
  }

  @Test func readOnlyActiveHasNoCompletionToggle() {
    let presenter = TaskItemPresenter(task: makeTask(), kind: .active(onComplete: nil))
    #expect(!presenter.showsCompletionToggle)
    #expect(presenter.onComplete == nil)
  }

  @Test func completedExposesRestoreAndDelete() {
    var restored = false
    var deleted = false
    let presenter = TaskItemPresenter(
      task: makeTask(),
      kind: .completed(onRestore: { restored = true }, onDelete: { deleted = true }))
    #expect(presenter.canDelete)
    #expect(!presenter.showsCompletionToggle)
    presenter.onRestore?()
    presenter.onDelete?()
    #expect(restored)
    #expect(deleted)
  }

  @Test func completedWithoutDeleteHandlerCannotDelete() {
    let presenter = TaskItemPresenter(
      task: makeTask(), kind: .completed(onRestore: {}, onDelete: nil))
    #expect(!presenter.canDelete)
    #expect(presenter.onDelete == nil)
  }

  // MARK: - Due date

  @Test func dueDateSuppressedWhenCompleted() {
    let due = Date(timeIntervalSinceNow: 3600)
    let presenter = TaskItemPresenter(
      task: makeTask(dueDate: due, completedAt: Date()),
      kind: .completed(onRestore: {}, onDelete: nil))
    #expect(presenter.dueDate == nil)
  }

  @Test func dueDateShownWhenActive() {
    let due = Date(timeIntervalSinceNow: 3600)
    let presenter = TaskItemPresenter(
      task: makeTask(dueDate: due), kind: .active(onComplete: {}))
    #expect(presenter.dueDate == due)
  }

  @Test func urgencyReflectsTodayAndPast() {
    let past = Date(timeIntervalSinceNow: -86_400)
    let today = Date()
    let future = Date(timeIntervalSinceNow: 7 * 86_400)

    #expect(
      TaskItemPresenter(task: makeTask(dueDate: past), kind: .active(onComplete: {})).dueIsUrgent)
    #expect(
      TaskItemPresenter(task: makeTask(dueDate: today), kind: .active(onComplete: {})).dueIsUrgent)
    #expect(
      !TaskItemPresenter(task: makeTask(dueDate: future), kind: .active(onComplete: {}))
        .dueIsUrgent)
    #expect(
      !TaskItemPresenter(task: makeTask(dueDate: nil), kind: .active(onComplete: {})).dueIsUrgent)
  }

  // MARK: - Lineage

  @Test func displayLineageNilWhenAbsent() {
    let presenter = TaskItemPresenter(task: makeTask(), kind: .active(onComplete: {}))
    #expect(presenter.displayLineage == nil)
  }

  @Test func displayLineageNilWhenEmpty() {
    let empty = TaskLineage(providerIcon: nil, listName: nil, sectionName: nil)
    let presenter = TaskItemPresenter(
      task: makeTask(), kind: .active(onComplete: {}), lineage: empty)
    #expect(presenter.displayLineage == nil)
  }

  @Test func displayLineagePassesThroughWhenPopulated() {
    let lineage = TaskLineage(providerIcon: "tray", listName: "Work", sectionName: nil)
    let presenter = TaskItemPresenter(
      task: makeTask(), kind: .active(onComplete: {}), lineage: lineage)
    #expect(presenter.displayLineage?.contextLabel == "Work")
  }

  // MARK: - Completed subtitle

  @Test func completedSubtitleFallsBackWhenDateMissing() {
    let presenter = TaskItemPresenter(
      task: makeTask(completedAt: nil), kind: .completed(onRestore: {}, onDelete: nil))
    #expect(presenter.completedSubtitle == "Unknown date")
  }

  @Test func completedSubtitleFormatsRelativeDate() {
    let presenter = TaskItemPresenter(
      task: makeTask(completedAt: Date(timeIntervalSinceNow: -2 * 86_400)),
      kind: .completed(onRestore: {}, onDelete: nil))
    #expect(presenter.completedSubtitle != "Unknown date")
    #expect(!presenter.completedSubtitle.isEmpty)
  }

  // MARK: - Priority glyph mapping (canonical across every surface)

  @Test func priorityIconIsGlyphDistinctAcrossLevels() {
    #expect(TaskPriority.none.icon == nil)
    #expect(TaskPriority.lowest.icon == "exclamationmark")
    #expect(TaskPriority.low.icon == "exclamationmark")
    #expect(TaskPriority.medium.icon == "exclamationmark.2")
    #expect(TaskPriority.high.icon == "exclamationmark.3")
    #expect(TaskPriority.highest.icon == "exclamationmark.triangle.fill")
  }
}
