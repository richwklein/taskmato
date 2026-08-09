//
//  ObsidianTaskLineFormatterTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

@Suite("ObsidianTaskLineFormatter")
struct ObsidianTaskLineFormatterTests {

  private let formatter = ObsidianTaskLineFormatter()
  private let parser = ObsidianTaskParser()
  private let dummyList = TaskList(id: "tasks.md", providerID: "obsidian", name: "tasks")

  private func date(_ string: String) -> Date {
    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withFullDate]
    return iso.date(from: string)!
  }

  private func roundTrip(_ line: String) -> TaskItem {
    let items = parser.parse(
      content: line,
      providerID: "obsidian",
      fileRelativePath: "tasks.md",
      vaultName: "MyVault",
      list: dummyList
    ).items
    return items[0]
  }

  // MARK: - Title only

  @Test func formatsTitleOnly() {
    let line = formatter.formatLine(title: "Write unit tests")
    #expect(line == "- [ ] Write unit tests")
  }

  @Test func formatsCompletedCheckbox() {
    let line = formatter.formatLine(title: "Done", checkbox: "x")
    #expect(line == "- [x] Done")
  }

  @Test func formatsOrderedTaskWhenNumberProvided() {
    let line = formatter.formatLine(title: "Write unit tests", orderedNumber: 3)
    #expect(line == "3. [ ] Write unit tests")
  }

  @Test func trimsTitleWhitespace() {
    let line = formatter.formatLine(title: "  Padded  ")
    #expect(line == "- [ ] Padded")
  }

  // MARK: - Priority

  @Test(
    arguments: [
      (TaskPriority.highest, "🔺"),
      (TaskPriority.high, "⏫"),
      (TaskPriority.medium, "🔼"),
      (TaskPriority.low, "🔽"),
      (TaskPriority.lowest, "⏬"),
    ]
  )
  func formatsEachPriorityEmoji(priority: TaskPriority, emoji: String) {
    let line = formatter.formatLine(title: "Task", priority: priority)
    #expect(line == "- [ ] Task \(emoji)")
  }

  @Test func omitsEmojiForNonePriority() {
    let line = formatter.formatLine(title: "Task", priority: .none)
    #expect(line == "- [ ] Task")
  }

  // MARK: - Dates

  @Test func formatsDueDate() {
    let line = formatter.formatLine(title: "Task", dueDate: date("2026-08-08"))
    #expect(line == "- [ ] Task 📅 2026-08-08")
  }

  @Test func formatsScheduledDate() {
    let line = formatter.formatLine(title: "Task", scheduledDate: date("2026-08-08"))
    #expect(line == "- [ ] Task ⏰ 2026-08-08")
  }

  @Test func formatsStartDate() {
    let line = formatter.formatLine(title: "Task", startDate: date("2026-08-08"))
    #expect(line == "- [ ] Task 🛫 2026-08-08")
  }

  @Test func formatsAllFieldsInOrder() {
    let line = formatter.formatLine(
      title: "Task",
      priority: .high,
      startDate: date("2026-08-01"),
      scheduledDate: date("2026-08-05"),
      dueDate: date("2026-08-08")
    )
    #expect(line == "- [ ] Task ⏫ 🛫 2026-08-01 ⏰ 2026-08-05 📅 2026-08-08")
  }

  // MARK: - Round-trip through the parser

  @Test func roundTripsTitlePriorityAndDueDate() {
    let line = formatter.formatLine(
      title: "Ship it", priority: .medium, dueDate: date("2026-08-08"))
    let item = roundTrip(line)
    #expect(item.title == "Ship it")
    #expect(item.priority == .medium)
    #expect(item.dueDate == date("2026-08-08"))
  }

  @Test func roundTripsAllDateFields() {
    let line = formatter.formatLine(
      title: "Ship it",
      startDate: date("2026-08-01"),
      scheduledDate: date("2026-08-05"),
      dueDate: date("2026-08-08")
    )
    let item = roundTrip(line)
    #expect(item.startDate == date("2026-08-01"))
    #expect(item.scheduledDate == date("2026-08-05"))
    #expect(item.dueDate == date("2026-08-08"))
  }

  // MARK: - Note lines

  @Test func formatsNoteLinesWithFourSpaceIndent() {
    let lines = formatter.formatNoteLines("First note\nSecond note")
    #expect(lines == ["    First note", "    Second note"])
  }

  @Test func formatsSingleLineNote() {
    let lines = formatter.formatNoteLines("Just one line")
    #expect(lines == ["    Just one line"])
  }

  @Test func returnsEmptyArrayForBlankNotes() {
    #expect(formatter.formatNoteLines("").isEmpty)
    #expect(formatter.formatNoteLines("   \n  ").isEmpty)
  }

  @Test func trimsSurroundingWhitespaceFromNotes() {
    let lines = formatter.formatNoteLines("\n  Note text  \n")
    #expect(lines == ["    Note text"])
  }
}
