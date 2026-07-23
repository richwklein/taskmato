//
//  TaskSorterTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

// MARK: - Factory

private func makeSortItem(
  providerID: String = "p",
  nativeID: String,
  title: String,
  priority: TaskPriority = .none,
  dueDate: Date? = nil,
  createdAt: Date? = nil,
  list: TaskList? = nil,
  section: String? = nil
) -> TaskItem {
  TaskItem(
    id: TaskRef(providerID: providerID, nativeID: nativeID),
    title: title,
    notes: nil,
    format: .plainText,
    priority: priority,
    dueDate: dueDate,
    scheduledDate: nil,
    startDate: nil,
    list: list,
    section: section,
    sourceURL: nil,
    completedAt: nil,
    createdAt: createdAt
  )
}

// MARK: - Tests

@Suite("TaskSorter")
struct TaskSorterTests {

  private let sorter = TaskSorter()

  // MARK: - Due Date

  @Test func sortByDueDateAscendingPutsNilLast() {
    let near = Date(timeIntervalSinceNow: 3600)
    let far = Date(timeIntervalSinceNow: 7200)
    let items = [
      makeSortItem(nativeID: "nil", title: "No Due"),
      makeSortItem(nativeID: "far", title: "Far", dueDate: far),
      makeSortItem(nativeID: "near", title: "Near", dueDate: near),
    ]
    let sorted = sorter.sorted(items, by: .dueDate, direction: .ascending)
    #expect(sorted.map(\.id.nativeID) == ["near", "far", "nil"])
  }

  @Test func sortByDueDateDescendingPutsNilLast() {
    let near = Date(timeIntervalSinceNow: 3600)
    let far = Date(timeIntervalSinceNow: 7200)
    let items = [
      makeSortItem(nativeID: "near", title: "Near", dueDate: near),
      makeSortItem(nativeID: "nil", title: "No Due"),
      makeSortItem(nativeID: "far", title: "Far", dueDate: far),
    ]
    let sorted = sorter.sorted(items, by: .dueDate, direction: .descending)
    #expect(sorted.map(\.id.nativeID) == ["far", "near", "nil"])
  }

  // MARK: - Priority

  @Test func sortByPriorityDescendingMatchesLegacyBehavior() {
    let near = Date(timeIntervalSinceNow: 3600)
    let far = Date(timeIntervalSinceNow: 7200)
    let items = [
      makeSortItem(nativeID: "low-nil", title: "A", priority: .low, dueDate: nil),
      makeSortItem(nativeID: "high-near", title: "B", priority: .high, dueDate: near),
      makeSortItem(nativeID: "high-far", title: "C", priority: .high, dueDate: far),
      makeSortItem(nativeID: "none-near", title: "D", priority: .none, dueDate: near),
    ]
    let sorted = sorter.sorted(items, by: .priority, direction: .descending)
    // high priority first, tie-broken by dueDate asc (nil last); then lower priorities
    #expect(sorted.map(\.id.nativeID) == ["high-near", "high-far", "low-nil", "none-near"])
  }

  @Test func sortByPriorityAscendingReversesPriority() {
    let items = [
      makeSortItem(nativeID: "high", title: "B", priority: .high),
      makeSortItem(nativeID: "none", title: "A", priority: .none),
      makeSortItem(nativeID: "low", title: "C", priority: .low),
    ]
    let sorted = sorter.sorted(items, by: .priority, direction: .ascending)
    #expect(sorted.map(\.id.nativeID) == ["none", "low", "high"])
  }

  // MARK: - Title

  @Test func sortByTitleUsesLocalizedStandardCompare() {
    let items = [
      makeSortItem(nativeID: "10", title: "Item 10"),
      makeSortItem(nativeID: "2", title: "Item 2"),
      makeSortItem(nativeID: "1", title: "Item 1"),
    ]
    let sorted = sorter.sorted(items, by: .title, direction: .ascending)
    // localizedStandardCompare treats "Item 2" < "Item 10" (numeric ordering)
    #expect(sorted.map(\.id.nativeID) == ["1", "2", "10"])
  }

  // MARK: - Creation Date

  @Test func sortByCreationDateAscendingPutsNilLast() {
    let earlier = Date(timeIntervalSinceNow: -7200)
    let later = Date(timeIntervalSinceNow: -3600)
    let items = [
      makeSortItem(nativeID: "nil", title: "No Date"),
      makeSortItem(nativeID: "later", title: "Later", createdAt: later),
      makeSortItem(nativeID: "earlier", title: "Earlier", createdAt: earlier),
    ]
    let sorted = sorter.sorted(items, by: .creationDate, direction: .ascending)
    #expect(sorted.map(\.id.nativeID) == ["earlier", "later", "nil"])
  }

  // MARK: - Tiebreaker

  @Test func sortIsDeterministicForEqualKeys() {
    let sameDate = Date(timeIntervalSinceNow: 3600)
    let items = [
      makeSortItem(nativeID: "z", title: "Same Title", dueDate: sameDate),
      makeSortItem(nativeID: "a", title: "Same Title", dueDate: sameDate),
      makeSortItem(nativeID: "m", title: "Same Title", dueDate: sameDate),
    ]
    let sorted = sorter.sorted(items, by: .dueDate, direction: .ascending)
    // All share the same dueDate and title; TaskRef (providerID/nativeID) is the final tiebreaker.
    // All have providerID "p", so nativeID order: "a" < "m" < "z".
    #expect(sorted.map(\.id.nativeID) == ["a", "m", "z"])
  }

  // MARK: - Section preservation

  @Test func preserveSectionsKeepsEncounterOrderAndSortsWithinSection() {
    let list = TaskList(id: "list1", providerID: "p", name: "List 1")
    let items = [
      makeSortItem(nativeID: "alpha-c", title: "C", list: list, section: "Alpha"),
      makeSortItem(nativeID: "alpha-a", title: "A", list: list, section: "Alpha"),
      makeSortItem(nativeID: "beta-d", title: "D", list: list, section: "Beta"),
      makeSortItem(nativeID: "beta-b", title: "B", list: list, section: "Beta"),
    ]
    let sorted = sorter.sorted(items, by: .title, direction: .ascending, preserveSections: true)
    // Sections maintain encounter order (Alpha before Beta); titles sorted within each section.
    #expect(sorted.map(\.id.nativeID) == ["alpha-a", "alpha-c", "beta-b", "beta-d"])
  }

  @Test func preserveSectionsTrueRespectsEncounterOrderOverSortKey() {
    let list = TaskList(id: "l1", providerID: "p", name: "L1")
    let earlier = Date(timeIntervalSinceNow: -7200)
    let later = Date(timeIntervalSinceNow: -3600)
    let items = [
      makeSortItem(
        nativeID: "alpha-later", title: "A", dueDate: later, list: list, section: "Alpha"),
      makeSortItem(
        nativeID: "beta-earlier", title: "B", dueDate: earlier, list: list, section: "Beta"),
    ]
    let sorted = sorter.sorted(items, by: .dueDate, direction: .ascending, preserveSections: true)
    // Alpha encountered first → its item stays ahead despite the later due date.
    #expect(sorted.map(\.id.nativeID) == ["alpha-later", "beta-earlier"])
  }

  @Test func preserveSectionsFalseSortsAcrossSectionBoundaries() {
    let list = TaskList(id: "l1", providerID: "p", name: "L1")
    let earlier = Date(timeIntervalSinceNow: -7200)
    let later = Date(timeIntervalSinceNow: -3600)
    let items = [
      makeSortItem(
        nativeID: "alpha-later", title: "A", dueDate: later, list: list, section: "Alpha"),
      makeSortItem(
        nativeID: "beta-earlier", title: "B", dueDate: earlier, list: list, section: "Beta"),
    ]
    let sorted = sorter.sorted(items, by: .dueDate, direction: .ascending, preserveSections: false)
    // Flat sort ignores section encounter order — beta-earlier has an earlier date.
    #expect(sorted.map(\.id.nativeID) == ["beta-earlier", "alpha-later"])
  }
}
