//
//  TaskClipboardServiceTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

// MARK: - Fakes

private final class FakeWritableProvider: WritableTaskProvider {
  let id: ProviderID = "fake-writable"
  let displayName = "Fake Writable"
  let icon = "square"
  let entitlement: ProviderEntitlement = .free

  private(set) var defaultListID: String?
  let contentFormat: ContentFormat = .markdown

  func authorize() async throws {}
  func lists() async throws -> [TaskList] { [] }
  func tasks(in _: TaskList?) async throws -> [TaskItem] { [] }
  func observe() -> AsyncStream<[TaskItem]>? { nil }
  func complete(_: TaskRef) async throws {}
  func reopen(_: TaskRef) async throws {}
  func addTask(_ draft: TaskDraft) -> TaskItem {
    TaskItem(
      id: TaskRef(providerID: id, nativeID: UUID().uuidString), title: draft.title, notes: nil,
      format: .plainText, priority: .none)
  }
  func setDefaultList(_ listID: String) { defaultListID = listID }
  @discardableResult
  func createList(name: String) -> TaskList {
    TaskList(id: UUID().uuidString, providerID: id, name: name)
  }
  func renameList(_: String, name _: String) {}
  func deleteList(_: String) {}
  func updateTask(_: TaskRef, draft _: TaskDraft) {}
  func deleteTask(_: TaskRef) {}
}

@Suite("TaskClipboardService")
struct TaskClipboardServiceTests {

  private let service = TaskClipboardService()

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

  // MARK: - payload(for:)

  @Test func payloadForTaskCapturesTheClipboardRelevantFields() {
    let task = makeTask()
    let payload = service.payload(for: task)
    #expect(payload.title == task.title)
    #expect(payload.notes == task.notes)
    #expect(payload.priority == task.priority)
    #expect(payload.dueDate == task.dueDate)
    #expect(payload.version == TaskClipboardPayload.currentVersion)
  }

  // MARK: - TaskClipboardPayload Codable round-trip + version envelope

  @Test func payloadRoundTripsThroughJSONCoding() throws {
    let payload = TaskClipboardPayload(
      title: "Ship it", notes: "Some notes", priority: .medium,
      dueDate: Date(timeIntervalSince1970: 500_000))
    let data = try JSONEncoder().encode(payload)
    let decoded = try JSONDecoder().decode(TaskClipboardPayload.self, from: data)
    #expect(decoded.version == payload.version)
    #expect(decoded.title == payload.title)
    #expect(decoded.notes == payload.notes)
    #expect(decoded.priority == payload.priority)
    #expect(decoded.dueDate == payload.dueDate)
  }

  @Test func newPayloadIsStampedWithTheCurrentVersion() {
    let payload = TaskClipboardPayload(
      title: "Title only", notes: nil, priority: .none, dueDate: nil)
    #expect(payload.version == TaskClipboardPayload.currentVersion)
  }

  // MARK: - canImport(_:)

  @Test func canImportAcceptsTheCurrentVersion() {
    let payload = TaskClipboardPayload(title: "T", notes: nil, priority: .none, dueDate: nil)
    #expect(service.canImport(payload))
  }

  @Test func canImportRejectsAnUnsupportedVersion() throws {
    let current = TaskClipboardPayload(title: "T", notes: nil, priority: .none, dueDate: nil)
    var data = try JSONEncoder().encode(current)
    var object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    object?["version"] = TaskClipboardPayload.currentVersion + 1
    data = try JSONSerialization.data(withJSONObject: object as Any)
    let futurePayload = try JSONDecoder().decode(TaskClipboardPayload.self, from: data)
    #expect(!service.canImport(futurePayload))
  }

  // MARK: - draft(from:listID:format:)

  @Test func draftFromPayloadMapsFieldsAndStampsListIDAndFormat() {
    let payload = TaskClipboardPayload(
      title: "Ship it", notes: "Some notes", priority: .medium,
      dueDate: Date(timeIntervalSince1970: 500_000))
    let draft = service.draft(from: payload, listID: "list-1", format: .markdown)
    #expect(draft.title == "Ship it")
    #expect(draft.notes == "Some notes")
    #expect(draft.priority == .medium)
    #expect(draft.dueDate == Date(timeIntervalSince1970: 500_000))
    #expect(draft.listID == "list-1")
    #expect(draft.format == .markdown)
  }

  @Test func draftFromPayloadMapsNilNotesToEmptyStringAndNilListIDToDefault() {
    let payload = TaskClipboardPayload(
      title: "Title only", notes: nil, priority: .none, dueDate: nil)
    let draft = service.draft(from: payload, listID: nil, format: .plainText)
    #expect(draft.notes.isEmpty)
    #expect(draft.listID == nil)
  }

  @Test func draftFromPayloadAlwaysMapsToAnActiveTask() {
    // TaskDraft has no completed/active field: mapping a payload never carries completion
    // state along, so a pasted task is always active by construction.
    let payload = TaskClipboardPayload(title: "Any task", notes: nil, priority: .none, dueDate: nil)
    let draft = service.draft(from: payload, listID: nil, format: .plainText)
    #expect(draft.title == "Any task")
  }

  @Test func draftFromPayloadOverwritesDueDateWithTodayWhenPastingUnderToday() {
    let payload = TaskClipboardPayload(
      title: "Due next week", notes: nil, priority: .none,
      dueDate: Date(timeIntervalSince1970: 500_000))
    let draft = service.draft(from: payload, listID: nil, format: .markdown, dueToday: true)
    #expect(draft.dueDate == Calendar.current.startOfDay(for: .now))
  }

  // MARK: - draft(fromPlainText:listID:format:)

  @Test func draftFromPlainTextIsTitleOnly() {
    let draft = service.draft(
      fromPlainText: "From another app", listID: "list-2", format: .markdown)
    #expect(draft.title == "From another app")
    #expect(draft.notes.isEmpty)
    #expect(draft.priority == .none)
    #expect(draft.dueDate == nil)
    #expect(draft.listID == "list-2")
    #expect(draft.format == .markdown)
  }

  @Test func draftFromPlainTextSetsDueTodayWhenPastingUnderToday() {
    let draft = service.draft(
      fromPlainText: "Quick task", listID: nil, format: .markdown, dueToday: true)
    #expect(draft.dueDate == Calendar.current.startOfDay(for: .now))
  }

  // MARK: - canCut / canDelete

  @Test func canCutReflectsWritability() {
    #expect(service.canCut(isWritable: true))
    #expect(!service.canCut(isWritable: false))
  }

  @Test func canDeleteReflectsWritability() {
    #expect(service.canDelete(isWritable: true))
    #expect(!service.canDelete(isWritable: false))
  }

  // MARK: - pasteTarget(for:listID:) / canPaste(target:)

  @Test func pasteTargetPackagesTheResolvedProviderAndListID() {
    let provider = FakeWritableProvider()
    let target = service.pasteTarget(for: provider, listID: "list-9")
    #expect(target != nil)
    #expect(target?.provider.id == provider.id)
    #expect(target?.listID == "list-9")
  }

  @Test func pasteTargetIsNilWhenNoProviderIsResolved() {
    let target = service.pasteTarget(for: nil, listID: "list-9")
    #expect(target == nil)
  }

  @Test func canPasteReflectsWhetherATargetWasResolved() {
    let provider = FakeWritableProvider()
    #expect(service.canPaste(target: service.pasteTarget(for: provider, listID: nil)))
    #expect(!service.canPaste(target: service.pasteTarget(for: nil, listID: nil)))
  }
}
