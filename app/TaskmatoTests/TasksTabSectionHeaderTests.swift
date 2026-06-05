//
//  TasksTabSectionHeaderTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

@Suite("sectionHeader(listName:sectionName:isMultiList:)")
struct TasksTabSectionHeaderTests {

  // MARK: - Single list

  @Test func headerIsSectionNameWhenSingleListHasSection() {
    #expect(
      sectionHeader(listName: "Work", sectionName: "In Progress", isMultiList: false)
        == "In Progress")
  }

  @Test func headerIsListNameWhenSingleListHasNoSection() {
    #expect(sectionHeader(listName: "Personal", sectionName: nil, isMultiList: false) == "Personal")
  }

  // MARK: - Multiple lists

  @Test func headerIsListColonSectionWhenMultipleListsHaveSection() {
    #expect(
      sectionHeader(listName: "Work", sectionName: "In Progress", isMultiList: true)
        == "Work: In Progress")
  }

  @Test func headerIsListNameWhenMultipleListsHaveNoSection() {
    #expect(sectionHeader(listName: "Work", sectionName: nil, isMultiList: true) == "Work")
  }
}
