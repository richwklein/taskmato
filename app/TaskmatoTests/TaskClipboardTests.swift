//
//  TaskClipboardTests.swift
//  TaskmatoTests
//

import AppKit
import Foundation
import Testing

@testable import Taskmato

@Suite("TaskClipboard")
struct TaskClipboardTests {

  /// A uniquely named pasteboard scoped to a single test, so the system general pasteboard is
  /// never touched.
  private func makePasteboard() -> NSPasteboard {
    NSPasteboard(name: NSPasteboard.Name(UUID().uuidString))
  }

  private func makeTask(
    title: String = "Write tests",
    notes: String? = "Cover the payload mapping",
    priority: TaskPriority = .high,
    dueDate: Date? = Date(timeIntervalSince1970: 1_000_000)
  ) -> TaskItem {
    TaskItem(
      id: TaskRef(providerID: "local", nativeID: "abc"),
      title: title,
      notes: notes,
      format: .plainText,
      priority: priority,
      dueDate: dueDate,
      scheduledDate: nil,
      startDate: nil,
      list: nil,
      section: nil,
      sourceURL: nil,
      completedAt: nil,
      createdAt: nil
    )
  }

  // MARK: - TaskClipboardPayload

  @Test func payloadFromTaskCapturesTheFourFields() {
    let task = makeTask()
    let payload = TaskClipboardPayload(from: task)
    #expect(payload.title == task.title)
    #expect(payload.notes == task.notes)
    #expect(payload.priority == task.priority)
    #expect(payload.dueDate == task.dueDate)
  }

  @Test func makeDraftMapsFieldsAndStampsListIDAndFormat() {
    let payload = TaskClipboardPayload(
      title: "Ship it", notes: "Some notes", priority: .medium,
      dueDate: Date(timeIntervalSince1970: 500_000))
    let draft = payload.makeDraft(listID: "list-1", format: .markdown)
    #expect(draft.title == "Ship it")
    #expect(draft.notes == "Some notes")
    #expect(draft.priority == .medium)
    #expect(draft.dueDate == Date(timeIntervalSince1970: 500_000))
    #expect(draft.listID == "list-1")
    #expect(draft.format == .markdown)
  }

  @Test func makeDraftMapsNilNotesToEmptyString() {
    let payload = TaskClipboardPayload(
      title: "Title only", notes: nil, priority: .none, dueDate: nil)
    let draft = payload.makeDraft(listID: nil, format: .plainText)
    #expect(draft.notes.isEmpty)
    #expect(draft.listID == nil)
  }

  // MARK: - Copy / readPayload round trip

  @Test func copyThenReadPayloadRoundTripsTheFullPayload() {
    let pasteboard = makePasteboard()
    let task = makeTask()
    TaskClipboard.copy(task, to: pasteboard)
    let payload = TaskClipboard.readPayload(from: pasteboard)
    #expect(payload?.title == task.title)
    #expect(payload?.notes == task.notes)
    #expect(payload?.priority == task.priority)
    #expect(payload?.dueDate == task.dueDate)
  }

  @Test func copyWritesAPlainTextStringEqualToTheTitle() {
    let pasteboard = makePasteboard()
    let task = makeTask(title: "Interop title")
    TaskClipboard.copy(task, to: pasteboard)
    #expect(pasteboard.string(forType: .string) == "Interop title")
  }

  @Test func readPayloadFallsBackToTitleOnlyWhenOnlyPlainTextIsPresent() {
    let pasteboard = makePasteboard()
    pasteboard.clearContents()
    pasteboard.setString("From another app", forType: .string)
    let payload = TaskClipboard.readPayload(from: pasteboard)
    #expect(payload?.title == "From another app")
    #expect(payload?.notes == nil)
    #expect(payload?.priority == TaskPriority.none)
    #expect(payload?.dueDate == nil)
  }

  @Test func readPayloadReturnsNilForAnEmptyPasteboard() {
    let pasteboard = makePasteboard()
    pasteboard.clearContents()
    #expect(TaskClipboard.readPayload(from: pasteboard) == nil)
  }

  @Test func readPayloadReturnsNilWhenOnlyEmptyPlainTextIsPresent() {
    let pasteboard = makePasteboard()
    pasteboard.clearContents()
    pasteboard.setString("", forType: .string)
    let payload = TaskClipboard.readPayload(from: pasteboard)
    #expect(payload == nil)
  }
}
