//
//  ObsidianProviderWritableTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

// MARK: - Helpers

@MainActor
private func makeVault() throws -> URL {
  let dir = FileManager.default.temporaryDirectory
    .appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
  return dir
}

@MainActor
private func write(_ content: String, at relativePath: String, in vault: URL) throws {
  let dest = vault.appending(path: relativePath)
  let parent = dest.deletingLastPathComponent()
  try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
  try Data(content.utf8).write(to: dest, options: [])
}

@MainActor
private func read(_ relativePath: String, in vault: URL) throws -> String {
  try String(contentsOf: vault.appending(path: relativePath), encoding: .utf8)
}

@MainActor
private func makeProvider(vaultURL: URL?, defaultListID: String? = nil) -> ObsidianProvider {
  ObsidianProvider(
    store: SettingsStore(defaults: UserDefaults(suiteName: UUID().uuidString)!),
    vaultURL: vaultURL,
    defaultListID: defaultListID
  )
}

// MARK: - Writable tests

@Suite("ObsidianProvider — writable")
@MainActor
struct ObsidianProviderWritableTests {

  // MARK: contentFormat

  @Test func contentFormatIsMarkdown() {
    let provider = makeProvider(vaultURL: nil)
    #expect(provider.contentFormat == .markdown)
  }

  // MARK: defaultListID

  @Test func defaultListIDNilWhenUnset() {
    let provider = makeProvider(vaultURL: nil)
    #expect(provider.defaultListID == nil)
  }

  @Test func defaultListIDReflectsOverrideAfterSetDefaultList() async throws {
    let vault = try makeVault()
    defer { try? FileManager.default.removeItem(at: vault) }
    try write("- [ ] Task", at: "tasks.md", in: vault)
    let provider = makeProvider(vaultURL: vault)
    try await provider.setDefaultList("tasks.md")
    #expect(provider.defaultListID == "tasks.md")
  }

  @Test func setDefaultListThrowsForUnknownFile() async throws {
    let vault = try makeVault()
    defer { try? FileManager.default.removeItem(at: vault) }
    let provider = makeProvider(vaultURL: vault)
    await #expect(throws: ObsidianProviderError.self) {
      try await provider.setDefaultList("nonexistent.md")
    }
  }

  // MARK: addTask

  @Test func addTaskTargetsDraftListIDWhenSet() async throws {
    let vault = try makeVault()
    defer { try? FileManager.default.removeItem(at: vault) }
    try write("- [ ] Existing", at: "work.md", in: vault)
    try write("- [ ] Existing", at: "personal.md", in: vault)
    let provider = makeProvider(vaultURL: vault)
    var draft = TaskDraft()
    draft.title = "Buy milk"
    draft.listID = "personal.md"
    let item = try await provider.addTask(draft)
    #expect(item.list?.id == "personal.md")
    let content = try read("personal.md", in: vault)
    #expect(content.contains("- [ ] Buy milk"))
  }

  @Test func addTaskFallsBackToDefaultListID() async throws {
    let vault = try makeVault()
    defer { try? FileManager.default.removeItem(at: vault) }
    try write("- [ ] Existing", at: "tasks.md", in: vault)
    let provider = makeProvider(vaultURL: vault, defaultListID: "tasks.md")
    var draft = TaskDraft()
    draft.title = "Buy milk"
    let item = try await provider.addTask(draft)
    #expect(item.list?.id == "tasks.md")
  }

  @Test func addTaskThrowsWhenNoListResolves() async throws {
    let vault = try makeVault()
    defer { try? FileManager.default.removeItem(at: vault) }
    let provider = makeProvider(vaultURL: vault)
    var draft = TaskDraft()
    draft.title = "Buy milk"
    await #expect(throws: ObsidianProviderError.self) {
      try await provider.addTask(draft)
    }
  }

  @Test func addTaskMapsTitlePriorityAndDueDate() async throws {
    let vault = try makeVault()
    defer { try? FileManager.default.removeItem(at: vault) }
    try write("- [ ] Existing", at: "tasks.md", in: vault)
    let provider = makeProvider(vaultURL: vault, defaultListID: "tasks.md")
    var draft = TaskDraft()
    draft.title = "Buy milk"
    draft.priority = .high
    draft.dueDate = Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 15))
    let item = try await provider.addTask(draft)
    #expect(item.title == "Buy milk")
    #expect(item.priority == .high)
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    let comps = cal.dateComponents([.year, .month, .day], from: item.dueDate!)
    #expect(comps.year == 2026)
    #expect(comps.month == 6)
    #expect(comps.day == 15)
  }

  @Test func addTaskWithNotesWritesIndentedContinuationLines() async throws {
    let vault = try makeVault()
    defer { try? FileManager.default.removeItem(at: vault) }
    try write("- [ ] Existing", at: "tasks.md", in: vault)
    let provider = makeProvider(vaultURL: vault, defaultListID: "tasks.md")
    var draft = TaskDraft()
    draft.title = "Buy milk"
    draft.notes = "2%\nOne gallon"
    let item = try await provider.addTask(draft)
    #expect(item.notes == "2%\nOne gallon")
    let content = try read("tasks.md", in: vault)
    #expect(content.contains("- [ ] Buy milk\n    2%\n    One gallon"))
  }

  @Test func addTaskWithNilSectionAppendsAtEndOfFile() async throws {
    let vault = try makeVault()
    defer { try? FileManager.default.removeItem(at: vault) }
    try write(
      """
      ## Section A
      - [ ] First

      ## Section B
      - [ ] Second
      """, at: "tasks.md", in: vault)
    let provider = makeProvider(vaultURL: vault, defaultListID: "tasks.md")
    var draft = TaskDraft()
    draft.title = "Top level"
    _ = try await provider.addTask(draft)
    let content = try read("tasks.md", in: vault)
    #expect(content.hasSuffix("- [ ] Top level"))
  }

  @Test func addTaskToExistingSectionAppendsAfterLastLineInBlock() async throws {
    let vault = try makeVault()
    defer { try? FileManager.default.removeItem(at: vault) }
    try write(
      """
      ## Section A
      - [ ] First
      - [ ] Second

      ## Section B
      - [ ] Third
      """, at: "tasks.md", in: vault)
    let provider = makeProvider(vaultURL: vault, defaultListID: "tasks.md")
    var draft = TaskDraft()
    draft.title = "New task"
    draft.section = "Section A"
    let item = try await provider.addTask(draft)
    #expect(item.section == "Section A")
    let content = try read("tasks.md", in: vault)
    let expected = """
      ## Section A
      - [ ] First
      - [ ] Second
      - [ ] New task

      ## Section B
      - [ ] Third
      """
    #expect(content == expected)
  }

  @Test func addTaskToSectionAtEndOfFileInsertsAfterHeading() async throws {
    let vault = try makeVault()
    defer { try? FileManager.default.removeItem(at: vault) }
    try write("## Empty Section", at: "tasks.md", in: vault)
    let provider = makeProvider(vaultURL: vault, defaultListID: "tasks.md")
    var draft = TaskDraft()
    draft.title = "First in section"
    draft.section = "Empty Section"
    _ = try await provider.addTask(draft)
    let content = try read("tasks.md", in: vault)
    #expect(content == "## Empty Section\n- [ ] First in section")
  }

  @Test func addTaskThrowsSectionNotFoundForUnknownHeading() async throws {
    let vault = try makeVault()
    defer { try? FileManager.default.removeItem(at: vault) }
    try write("- [ ] Existing", at: "tasks.md", in: vault)
    let provider = makeProvider(vaultURL: vault, defaultListID: "tasks.md")
    var draft = TaskDraft()
    draft.title = "New task"
    draft.section = "Nonexistent"
    await #expect(throws: ObsidianProviderError.self) {
      try await provider.addTask(draft)
    }
  }

  // MARK: updateTask

  @Test func updateTaskInPlaceRewritesLineWithoutMoving() async throws {
    let vault = try makeVault()
    defer { try? FileManager.default.removeItem(at: vault) }
    try write("- [ ] Original", at: "tasks.md", in: vault)
    let provider = makeProvider(vaultURL: vault)
    let ref = TaskRef(providerID: "obsidian", nativeID: "tasks.md:1")
    var draft = TaskDraft()
    draft.title = "Updated"
    try await provider.updateTask(ref, draft: draft)
    let content = try read("tasks.md", in: vault)
    #expect(content == "- [ ] Updated")
  }

  @Test func updateTaskMovesToADifferentSectionInSameFile() async throws {
    let vault = try makeVault()
    defer { try? FileManager.default.removeItem(at: vault) }
    try write(
      """
      ## Section A
      - [ ] Move me

      ## Section B
      - [ ] Existing
      """, at: "tasks.md", in: vault)
    let provider = makeProvider(vaultURL: vault)
    let ref = TaskRef(providerID: "obsidian", nativeID: "tasks.md:2")
    var draft = TaskDraft()
    draft.title = "Move me"
    draft.section = "Section B"
    try await provider.updateTask(ref, draft: draft)
    let content = try read("tasks.md", in: vault)
    let expected = """
      ## Section A

      ## Section B
      - [ ] Existing
      - [ ] Move me
      """
    #expect(content == expected)
  }

  @Test func updateTaskMovesToADifferentFile() async throws {
    let vault = try makeVault()
    defer { try? FileManager.default.removeItem(at: vault) }
    try write("- [ ] Move me", at: "source.md", in: vault)
    try write("- [ ] Existing", at: "dest.md", in: vault)
    let provider = makeProvider(vaultURL: vault)
    let ref = TaskRef(providerID: "obsidian", nativeID: "source.md:1")
    var draft = TaskDraft()
    draft.title = "Move me"
    draft.listID = "dest.md"
    try await provider.updateTask(ref, draft: draft)
    #expect(try read("source.md", in: vault).isEmpty)
    #expect(try read("dest.md", in: vault) == "- [ ] Existing\n- [ ] Move me")
  }

  @Test func updateTaskThrowsForStaleRef() async throws {
    let vault = try makeVault()
    defer { try? FileManager.default.removeItem(at: vault) }
    try write("- [ ] Original", at: "tasks.md", in: vault)
    let provider = makeProvider(vaultURL: vault)
    let ref = TaskRef(providerID: "obsidian", nativeID: "tasks.md:5")
    var draft = TaskDraft()
    draft.title = "Updated"
    await #expect(throws: ObsidianProviderError.self) {
      try await provider.updateTask(ref, draft: draft)
    }
  }

  // MARK: deleteTask

  @Test func deleteTaskRemovesLine() async throws {
    let vault = try makeVault()
    defer { try? FileManager.default.removeItem(at: vault) }
    try write("- [ ] First\n- [ ] Second", at: "tasks.md", in: vault)
    let provider = makeProvider(vaultURL: vault)
    let ref = TaskRef(providerID: "obsidian", nativeID: "tasks.md:1")
    try await provider.deleteTask(ref)
    let content = try read("tasks.md", in: vault)
    #expect(content == "- [ ] Second")
  }

  @Test func deleteTaskRemovesIndentedNoteLinesToo() async throws {
    let vault = try makeVault()
    defer { try? FileManager.default.removeItem(at: vault) }
    try write(
      "- [ ] First\n    Note line\n- [ ] Second", at: "tasks.md", in: vault)
    let provider = makeProvider(vaultURL: vault)
    let ref = TaskRef(providerID: "obsidian", nativeID: "tasks.md:1")
    try await provider.deleteTask(ref)
    let content = try read("tasks.md", in: vault)
    #expect(content == "- [ ] Second")
  }

  @Test func deleteTaskThrowsForUnknownRef() async throws {
    let vault = try makeVault()
    defer { try? FileManager.default.removeItem(at: vault) }
    try write("- [ ] Task", at: "tasks.md", in: vault)
    let provider = makeProvider(vaultURL: vault)
    let ref = TaskRef(providerID: "obsidian", nativeID: "tasks.md:99")
    await #expect(throws: ObsidianProviderError.self) {
      try await provider.deleteTask(ref)
    }
  }
}
