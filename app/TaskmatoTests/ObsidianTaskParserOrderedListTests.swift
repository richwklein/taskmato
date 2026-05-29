//
//  ObsidianTaskParserOrderedListTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

@Suite("ObsidianTaskParser — ordered list tasks")
struct ObsidianTaskParserOrderedListTests {

  private let parser = ObsidianTaskParser()
  private let providerID = "obsidian"
  private let dummyList = TaskList(id: "tasks.md", providerID: "obsidian", name: "tasks")

  private func parse(_ content: String) -> [TaskItem] {
    parser.parse(
      content: content,
      providerID: providerID,
      fileRelativePath: "tasks.md",
      vaultName: "MyVault",
      list: dummyList
    ).items
  }

  @Test func parsesOrderedIncompleteTask() {
    let tasks = parse("1. [ ] First item")
    #expect(tasks.count == 1)
    #expect(tasks[0].title == "First item")
  }

  @Test func parsesMultiDigitOrderedTask() {
    let tasks = parse("10. [ ] Tenth item")
    #expect(tasks.count == 1)
    #expect(tasks[0].title == "Tenth item")
  }

  @Test func skipsOrderedCompletedTask() {
    #expect(parse("1. [x] Done item").isEmpty)
    #expect(parse("1. [X] Done item").isEmpty)
  }

  @Test func mixedOrderedAndUnordered() {
    let content = """
      1. [ ] Ordered task
      - [ ] Unordered task
      2. [x] Completed ordered
      """
    let tasks = parse(content)
    #expect(tasks.count == 2)
    #expect(tasks[0].title == "Ordered task")
    #expect(tasks[1].title == "Unordered task")
  }

  @Test func orderedTaskWithPriority() {
    let tasks = parse("1. [ ] Important ⏫")
    #expect(tasks[0].priority == .high)
    #expect(tasks[0].title == "Important")
  }

  @Test func orderedTaskWithDueDate() {
    let tasks = parse("3. [ ] Task 📅 2025-12-31")
    #expect(tasks[0].dueDate != nil)
    #expect(tasks[0].title == "Task")
  }

  @Test func orderedTaskNativeIDUsesLineNumber() {
    let tasks = parse("1. [ ] Task at line 1")
    #expect(tasks[0].id.nativeID == "tasks.md:1")
  }

  @Test func orderedTaskSectionAssignment() {
    let content = """
      ## Goals
      1. [ ] First goal
      2. [ ] Second goal
      """
    let tasks = parse(content)
    #expect(tasks.count == 2)
    #expect(tasks[0].section == "Goals")
    #expect(tasks[1].section == "Goals")
  }
}
