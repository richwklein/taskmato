//
//  ObsidianTaskParserTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

@Suite("ObsidianTaskParser")
struct ObsidianTaskParserTests {

  private let parser = ObsidianTaskParser()
  private let providerID = "obsidian"
  private let dummyList = TaskList(id: "tasks.md", providerID: "obsidian", name: "tasks")

  private func parse(_ content: String, relativePath: String = "tasks.md") -> [TaskItem] {
    parser.parse(
      content: content,
      providerID: providerID,
      fileRelativePath: relativePath,
      vaultName: "MyVault",
      list: dummyList
    ).items
  }

  // MARK: - Basic parsing

  @Test func parsesSimpleIncompleteTask() {
    let tasks = parse("- [ ] Write unit tests")
    #expect(tasks.count == 1)
    #expect(tasks[0].title == "Write unit tests")
    #expect(tasks[0].priority == .none)
    #expect(tasks[0].dueDate == nil)
  }

  @Test func skipsCompletedTaskLowercaseX() {
    let tasks = parse("- [x] Finished already")
    #expect(tasks.isEmpty)
  }

  @Test func skipsCompletedTaskUppercaseX() {
    let tasks = parse("- [X] Also finished")
    #expect(tasks.isEmpty)
  }

  @Test func parsesMultipleTasks() {
    let content = """
      - [ ] First task
      - [x] Done task
      - [ ] Third task
      """
    let tasks = parse(content)
    #expect(tasks.count == 2)
    #expect(tasks[0].title == "First task")
    #expect(tasks[1].title == "Third task")
  }

  @Test func ignoresNonTaskLines() {
    let content = """
      # Heading
      Some paragraph text.
      - [ ] Actual task
      * Bullet point (not a task)
      """
    let tasks = parse(content)
    #expect(tasks.count == 1)
    #expect(tasks[0].title == "Actual task")
  }

  @Test func emptyFileYieldsNoTasks() {
    #expect(parse("").isEmpty)
  }

  @Test func fileWithOnlyCompletedTasksYieldsEmpty() {
    let content = "- [x] Done\n- [X] Also done"
    #expect(parse(content).isEmpty)
  }

  // MARK: - Priority

  @Test func parsesHighestPriority() {
    let tasks = parse("- [ ] Important thing 🔺")
    #expect(tasks[0].priority == .highest)
    #expect(tasks[0].title == "Important thing")
  }

  @Test func parsesHighPriority() {
    let tasks = parse("- [ ] Urgent ⏫")
    #expect(tasks[0].priority == .high)
    #expect(tasks[0].title == "Urgent")
  }

  @Test func parsesMediumPriority() {
    let tasks = parse("- [ ] Normal 🔼")
    #expect(tasks[0].priority == .medium)
  }

  @Test func parsesLowPriority() {
    let tasks = parse("- [ ] Later 🔽")
    #expect(tasks[0].priority == .low)
  }

  @Test func parsesLowestPriority() {
    let tasks = parse("- [ ] Someday ⏬")
    #expect(tasks[0].priority == .lowest)
  }

  @Test func noPriorityEmojiDefaultsToNone() {
    let tasks = parse("- [ ] No priority here")
    #expect(tasks[0].priority == .none)
  }

  @Test func priorityCanAppearBeforeTitle() {
    let tasks = parse("- [ ] 🔺 Leading priority")
    #expect(tasks[0].priority == .highest)
    #expect(tasks[0].title == "Leading priority")
  }

  // MARK: - Dates

  @Test func parsesDueDate() throws {
    let tasks = parse("- [ ] Task 📅 2025-12-31")
    let due = try #require(tasks[0].dueDate)
    var utcCalendar = Calendar(identifier: .gregorian)
    utcCalendar.timeZone = TimeZone(identifier: "UTC")!
    let components = utcCalendar.dateComponents([.year, .month, .day], from: due)
    #expect(components.year == 2025)
    #expect(components.month == 12)
    #expect(components.day == 31)
  }

  @Test func parsesScheduledDate() {
    let tasks = parse("- [ ] Task ⏰ 2025-11-15")
    #expect(tasks[0].scheduledDate != nil)
  }

  @Test func parsesStartDate() {
    let tasks = parse("- [ ] Task 🛫 2025-10-01")
    #expect(tasks[0].startDate != nil)
  }

  @Test func parsesAllThreeDates() {
    let tasks = parse("- [ ] Task 📅 2025-12-31 ⏰ 2025-12-01 🛫 2025-11-01")
    #expect(tasks[0].dueDate != nil)
    #expect(tasks[0].scheduledDate != nil)
    #expect(tasks[0].startDate != nil)
  }

  @Test func malformedDateYieldsNil() {
    let tasks = parse("- [ ] Task 📅 not-a-date")
    #expect(tasks[0].dueDate == nil)
    #expect(tasks[0].title.contains("not-a-date"))
  }

  // MARK: - Notes

  @Test func parsesIndentedNotesWithFourSpaces() {
    let content = "- [ ] My task\n    First note line\n    Second note line"
    let tasks = parse(content)
    #expect(tasks[0].notes?.contains("First note line") == true)
    #expect(tasks[0].notes?.contains("Second note line") == true)
    #expect(tasks[0].format == .markdown)
  }

  @Test func parsesIndentedNotesWithTab() {
    let content = "- [ ] My task\n\tNote line"
    let tasks = parse(content)
    #expect(tasks[0].notes?.contains("Note line") == true)
  }

  @Test func notesStopAtNonIndentedLine() {
    let content = """
      - [ ] Task one
          Note for task one
      - [ ] Task two
      """
    let tasks = parse(content)
    #expect(tasks[0].notes?.contains("Note for task one") == true)
    #expect(tasks[1].notes == nil)
  }

  @Test func noNotesYieldsNil() {
    #expect(parse("- [ ] No notes here")[0].notes == nil)
  }

  @Test func whitespaceOnlyNotesYieldNil() {
    let content = "- [ ] Task\n    \n    "
    #expect(parse(content)[0].notes == nil)
  }

  @Test func nestedTaskLineBecomesNoteForParent() {
    // Indented task lines are treated as notes, not new tasks (matches obsidian-tasks behavior)
    let content = "- [ ] Parent task\n    - [ ] Nested item"
    let tasks = parse(content)
    #expect(tasks.count == 1)
    #expect(tasks[0].notes?.contains("- [ ] Nested item") == true)
  }

  // MARK: - Sections

  @Test func tasksBelowSubheadingGetSection() {
    let content = """
      ## Active
      - [ ] First task
      - [ ] Second task
      """
    let tasks = parse(content)
    #expect(tasks[0].section == "Active")
    #expect(tasks[1].section == "Active")
  }

  @Test func newSubheadingResetsSection() {
    let content = """
      ## Active
      - [ ] Task A
      ## Backlog
      - [ ] Task B
      """
    let tasks = parse(content)
    #expect(tasks[0].section == "Active")
    #expect(tasks[1].section == "Backlog")
  }

  @Test func tasksBeforeAnyHeadingHaveNilSection() {
    let tasks = parse("- [ ] Task with no section")
    #expect(tasks[0].section == nil)
  }

  // MARK: - H1 list name

  @Test func h1HeadingCapturedAsListName() {
    let content = "# My Tasks\n- [ ] Task"
    let result = parser.parse(
      content: content,
      providerID: providerID,
      fileRelativePath: "tasks.md",
      vaultName: "MyVault",
      list: dummyList
    )
    #expect(result.listName == "My Tasks")
  }

  @Test func noH1YieldsNilListName() {
    let result = parser.parse(
      content: "- [ ] Task",
      providerID: providerID,
      fileRelativePath: "tasks.md",
      vaultName: "MyVault",
      list: dummyList
    )
    #expect(result.listName == nil)
  }

  @Test func onlyFirstH1IsCaptured() {
    let content = "# First\n# Second\n- [ ] Task"
    let result = parser.parse(
      content: content,
      providerID: providerID,
      fileRelativePath: "tasks.md",
      vaultName: "MyVault",
      list: dummyList
    )
    #expect(result.listName == "First")
  }

  // MARK: - nativeID and providerID

  @Test func nativeIDContainsRelativePathAndLineNumber() {
    let tasks = parse("- [ ] Task at line 1")
    #expect(tasks[0].id.nativeID == "tasks.md:1")
  }

  @Test func nativeIDUsesCorrectLineNumber() {
    let content = "\n\n- [ ] Task at line 3"
    let tasks = parse(content)
    #expect(tasks[0].id.nativeID == "tasks.md:3")
  }

  @Test func nativeIDUsesSubpathRelativePath() {
    let tasks = parse("- [ ] Task", relativePath: "Projects/Work.md")
    #expect(tasks[0].id.nativeID == "Projects/Work.md:1")
  }

  @Test func providerIDIsPreserved() {
    let tasks = parse("- [ ] Task")
    #expect(tasks[0].id.providerID == "obsidian")
  }

  // MARK: - sourceURL

  @Test func sourceURLUsesObsidianScheme() {
    let tasks = parse("- [ ] Task")
    #expect(tasks[0].sourceURL?.scheme == "obsidian")
  }

  @Test func sourceURLContainsVaultName() {
    let tasks = parse("- [ ] Task")
    let query = tasks[0].sourceURL?.query(percentEncoded: false) ?? ""
    #expect(query.contains("MyVault"))
  }

  @Test func sourceURLStripsMarkdownExtension() {
    let tasks = parse("- [ ] Task", relativePath: "Projects/Work.md")
    let query = tasks[0].sourceURL?.query(percentEncoded: false) ?? ""
    #expect(query.contains("Projects/Work"))
    #expect(!query.contains(".md"))
  }

  // MARK: - List assignment

  @Test func taskAssignedToCorrectList() {
    let tasks = parse("- [ ] Task")
    #expect(tasks[0].list?.name == "tasks")
  }

  // MARK: - Format

  @Test func allObsidianTasksHaveMarkdownFormat() {
    let tasks = parse("- [ ] Task")
    #expect(tasks[0].format == .markdown)
  }

  // MARK: - Combined (full obsidian-tasks line)

  @Test func parseFullObsidianTasksLine() {
    let line = "- [ ] Review PR 🔺 📅 2025-12-31 ⏰ 2025-12-01 🛫 2025-11-01"
    let tasks = parse(line)
    #expect(tasks.count == 1)
    #expect(tasks[0].title == "Review PR")
    #expect(tasks[0].priority == .highest)
    #expect(tasks[0].dueDate != nil)
    #expect(tasks[0].scheduledDate != nil)
    #expect(tasks[0].startDate != nil)
  }

  @Test func fullTaskWithNotes() {
    let content = """
      - [ ] Review PR 🔺 📅 2025-12-31
          Check the diff carefully.
          Pay attention to the auth changes.
      """
    let tasks = parse(content)
    #expect(tasks[0].title == "Review PR")
    #expect(tasks[0].priority == .highest)
    #expect(tasks[0].dueDate != nil)
    #expect(tasks[0].notes?.contains("Check the diff carefully.") == true)
    #expect(tasks[0].notes?.contains("Pay attention to the auth changes.") == true)
  }
}

// MARK: - Completed task parsing

@Suite("ObsidianTaskParser — completed tasks")
struct ObsidianTaskParserCompletedTests {

  private let parser = ObsidianTaskParser()
  private let providerID = "obsidian"
  private let dummyList = TaskList(id: "tasks.md", providerID: "obsidian", name: "tasks")

  private func parseCompleted(
    _ content: String,
    relativePath: String = "tasks.md"
  ) -> [(item: TaskItem, completedAt: Date?)] {
    parser.parseCompleted(
      content: content,
      providerID: providerID,
      fileRelativePath: relativePath,
      vaultName: "MyVault",
      list: dummyList
    ).entries
  }

  @Test func parsesCompletedTaskLowercaseX() {
    let entries = parseCompleted("- [x] Finished task")
    #expect(entries.count == 1)
    #expect(entries[0].item.title == "Finished task")
  }

  @Test func parsesCompletedTaskUppercaseX() {
    let entries = parseCompleted("- [X] Also finished")
    #expect(entries.count == 1)
    #expect(entries[0].item.title == "Also finished")
  }

  @Test func skipsIncompleteTaskInCompletedScan() {
    #expect(parseCompleted("- [ ] Still pending").isEmpty)
  }

  @Test func skipsCancelledTaskInCompletedScan() {
    #expect(parseCompleted("- [-] Abandoned").isEmpty)
  }

  @Test func extractsCompletionDate() throws {
    let entries = parseCompleted("- [x] Done task ✅ 2025-12-31")
    let completedAt = try #require(entries[0].completedAt)
    var utcCalendar = Calendar(identifier: .gregorian)
    utcCalendar.timeZone = TimeZone(identifier: "UTC")!
    let comps = utcCalendar.dateComponents([.year, .month, .day], from: completedAt)
    #expect(comps.year == 2025)
    #expect(comps.month == 12)
    #expect(comps.day == 31)
  }

  @Test func completionEmojiRemovedFromTitle() {
    let entries = parseCompleted("- [x] Done task ✅ 2025-12-31")
    #expect(entries[0].item.title == "Done task")
    #expect(!entries[0].item.title.contains("✅"))
  }

  @Test func completedWithNoDateHasNilCompletedAt() {
    #expect(parseCompleted("- [x] Done without date")[0].completedAt == nil)
  }

  @Test func completedTaskExtractsPriority() {
    let entries = parseCompleted("- [x] High priority task ⏫")
    #expect(entries[0].item.priority == .high)
    #expect(entries[0].item.title == "High priority task")
  }

  @Test func completedTaskExtractsDueDate() {
    let entries = parseCompleted("- [x] Task 📅 2025-06-01")
    #expect(entries[0].item.dueDate != nil)
    #expect(entries[0].item.title == "Task")
  }

  @Test func completedTaskPreservesNativeID() {
    let entries = parseCompleted("- [x] Task", relativePath: "Projects/done.md")
    #expect(entries[0].item.id.nativeID == "Projects/done.md:1")
    #expect(entries[0].item.id.providerID == "obsidian")
  }

  @Test func completedTaskPreservesNotes() {
    let content = "- [x] Done\n    Some follow-up notes"
    let entries = parseCompleted(content)
    #expect(entries[0].item.notes?.contains("Some follow-up notes") == true)
  }

  @Test func mixedContentReturnsOnlyCompleted() {
    let content = """
      - [ ] Pending task
      - [x] Done one ✅ 2025-12-01
      - [x] Done two
      """
    let entries = parseCompleted(content)
    #expect(entries.count == 2)
    #expect(entries[0].item.title == "Done one")
    #expect(entries[1].item.title == "Done two")
  }

  @Test func parsesOrderedListCompletedTask() {
    let entries = parseCompleted("1. [x] Done ordered")
    #expect(entries.count == 1)
    #expect(entries[0].item.title == "Done ordered")
  }

  @Test func parsesOrderedListCompletedWithDate() {
    let entries = parseCompleted("2. [x] Done ✅ 2025-06-01")
    #expect(entries[0].item.title == "Done")
    #expect(entries[0].completedAt != nil)
  }
}
