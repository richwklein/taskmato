//
//  TasksTabSectionHeaderTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

@Suite("flatSections(from:) — header labels")
struct TasksTabSectionHeaderTests {

  // MARK: - Helpers

  private func makeGroup(listName: String, sectionName: String? = nil) -> TaskGroup {
    let section = TaskSection(
      id: sectionName ?? "_unsectioned_",
      name: sectionName,
      tasks: []
    )
    return TaskGroup(id: listName.lowercased(), listName: listName, sections: [section])
  }

  // MARK: - Single list

  @Test func headerIsSectionNameWhenSingleListHasSection() {
    let groups = [makeGroup(listName: "Work", sectionName: "In Progress")]
    let sections = flatSections(from: groups)
    #expect(sections.count == 1)
    #expect(sections[0].header == "In Progress")
  }

  @Test func headerIsListNameWhenSingleListHasNoSection() {
    let groups = [makeGroup(listName: "Personal")]
    let sections = flatSections(from: groups)
    #expect(sections.count == 1)
    #expect(sections[0].header == "Personal")
  }

  // MARK: - Multiple lists (global search spanning lists)

  @Test func headerIsListColonSectionWhenSearchSpansMultipleLists() {
    let groups = [
      makeGroup(listName: "Work", sectionName: "In Progress"),
      makeGroup(listName: "Personal", sectionName: "Today"),
    ]
    let sections = flatSections(from: groups)
    #expect(sections.count == 2)
    #expect(sections[0].header == "Work: In Progress")
    #expect(sections[1].header == "Personal: Today")
  }

  @Test func headerIsListNameWhenSearchSpansMultipleListsAndSectionIsAbsent() {
    let groups = [
      makeGroup(listName: "Work"),
      makeGroup(listName: "Personal"),
    ]
    let sections = flatSections(from: groups)
    #expect(sections.count == 2)
    #expect(sections[0].header == "Work")
    #expect(sections[1].header == "Personal")
  }
}
