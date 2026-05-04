//
//  TaskItemTests.swift
//  TaskmatoTests
//

import Testing
import Foundation
@testable import Taskmato

@Suite("TaskItem")
struct TaskItemTests {

  // MARK: - TaskRef

  @Test func taskRefCodableRoundTrip() throws {
    let ref = TaskRef(providerID: "reminders", nativeID: "abc-123")
    let data = try JSONEncoder().encode(ref)
    let decoded = try JSONDecoder().decode(TaskRef.self, from: data)
    #expect(decoded == ref)
  }

  @Test func taskRefHashableDistinguishesByProvider() {
    let a = TaskRef(providerID: "reminders", nativeID: "1")
    let b = TaskRef(providerID: "obsidian", nativeID: "1")
    #expect(a != b)
    #expect(Set([a, b]).count == 2)
  }

  // MARK: - TaskPriority

  @Test func taskPriorityOrdering() {
    #expect(TaskPriority.none < .lowest)
    #expect(TaskPriority.lowest < .low)
    #expect(TaskPriority.low < .medium)
    #expect(TaskPriority.medium < .high)
    #expect(TaskPriority.high < .highest)
  }

  @Test func taskPriorityCodableRoundTrip() throws {
    for priority in TaskPriority.allCases {
      let data = try JSONEncoder().encode(priority)
      let decoded = try JSONDecoder().decode(TaskPriority.self, from: data)
      #expect(decoded == priority)
    }
  }

  // MARK: - TaskItem

  @Test func taskItemMinimalCodableRoundTrip() throws {
    let item = TaskItem(
      id: TaskRef(providerID: "cli", nativeID: "x"),
      title: "Write tests",
      notes: nil,
      notesFormat: .plainText,
      priority: .none,
      dueDate: nil,
      scheduledDate: nil,
      startDate: nil,
      list: nil,
      section: nil,
      sourceURL: nil
    )
    let data = try JSONEncoder().encode(item)
    let decoded = try JSONDecoder().decode(TaskItem.self, from: data)
    #expect(decoded == item)
  }

  @Test func taskItemFullCodableRoundTrip() throws {
    let list = TaskList(id: "work", providerID: "obsidian", name: "Work")
    let item = TaskItem(
      id: TaskRef(providerID: "obsidian", nativeID: "vault/tasks.md:42"),
      title: "Review PR",
      notes: "Check the **diff** carefully",
      notesFormat: .markdown,
      priority: .high,
      dueDate: Date(timeIntervalSince1970: 1_000_000),
      scheduledDate: Date(timeIntervalSince1970: 900_000),
      startDate: Date(timeIntervalSince1970: 800_000),
      list: list,
      section: "In Progress",
      sourceURL: URL(string: "obsidian://open?vault=Main&file=tasks")
    )
    let data = try JSONEncoder().encode(item)
    let decoded = try JSONDecoder().decode(TaskItem.self, from: data)
    #expect(decoded == item)
  }

  @Test func taskItemNoteFormatCodableRoundTrip() throws {
    for format in [NoteFormat.plainText, NoteFormat.markdown] {
      let data = try JSONEncoder().encode(format)
      let decoded = try JSONDecoder().decode(NoteFormat.self, from: data)
      #expect(decoded == format)
    }
  }
}
