//
//  SwiftDataLocalTaskRepositoryTests.swift
//  TaskmatoTests
//

import Foundation
import SwiftData
import Testing

@testable import Taskmato

@Suite("SwiftDataLocalTaskRepository")
struct SwiftDataLocalTaskRepositoryTests {

  private func makeTask(
    title: String = "Task", notes: String? = nil, format: ContentFormat = .markdown,
    priority: TaskPriority = .none, dueDate: Date? = nil, scheduledDate: Date? = nil,
    startDate: Date? = nil, listID: UUID? = nil, isCompleted: Bool = false,
    completedAt: Date? = nil, createdAt: Date = Date()
  ) -> LocalTask {
    LocalTask(
      id: UUID(), title: title, notes: notes, format: format, priority: priority,
      dueDate: dueDate, scheduledDate: scheduledDate, startDate: startDate, listID: listID,
      isCompleted: isCompleted, completedAt: completedAt, createdAt: createdAt)
  }

  @Test func emptyStoreLoadAllReturnsEmpty() async throws {
    let repository = try SwiftDataLocalTaskRepository.makeInMemory()
    let store = try await repository.loadAll()
    #expect(store.lists.isEmpty)
    #expect(store.tasks.isEmpty)
    #expect(store.defaultListID == nil)
  }

  @Test func listOrderRoundTripsByCreatedAt() async throws {
    let repository = try SwiftDataLocalTaskRepository.makeInMemory()
    let first = LocalList(
      id: UUID(), name: "First", createdAt: Date(timeIntervalSinceReferenceDate: 0))
    let second = LocalList(
      id: UUID(), name: "Second", createdAt: Date(timeIntervalSinceReferenceDate: 1_000))
    // Save out of order on purpose.
    try await repository.save(
      LocalStore(lists: [second, first], tasks: [], defaultListID: first.id.uuidString))

    let loaded = try await repository.loadAll()
    #expect(loaded.lists.map(\.id) == [first.id, second.id])
  }

  @Test func defaultListIDRoundTripsThroughIsDefault() async throws {
    let repository = try SwiftDataLocalTaskRepository.makeInMemory()
    let list = LocalList(id: UUID(), name: "Work", createdAt: Date())
    try await repository.save(
      LocalStore(lists: [list], tasks: [], defaultListID: list.id.uuidString))

    let loaded = try await repository.loadAll()
    #expect(loaded.defaultListID == list.id.uuidString)
  }

  @Test func taskRoundTripsByCreatedAt() async throws {
    let repository = try SwiftDataLocalTaskRepository.makeInMemory()
    let first = makeTask(title: "First", createdAt: Date(timeIntervalSinceReferenceDate: 0))
    let second = makeTask(title: "Second", createdAt: Date(timeIntervalSinceReferenceDate: 1_000))
    try await repository.save(
      LocalStore(lists: [], tasks: [second, first], defaultListID: nil))

    let loaded = try await repository.loadAll()
    #expect(loaded.tasks.map(\.id) == [first.id, second.id])
  }

  @Test func saveReplacesRatherThanAppends() async throws {
    let repository = try SwiftDataLocalTaskRepository.makeInMemory()
    let listA = LocalList(id: UUID(), name: "A", createdAt: Date())
    let taskA = makeTask(title: "A")
    let storeA = LocalStore(lists: [listA], tasks: [taskA], defaultListID: listA.id.uuidString)
    try await repository.save(storeA)

    let listB = LocalList(id: UUID(), name: "B", createdAt: Date())
    let taskB = makeTask(title: "B")
    let storeB = LocalStore(lists: [listB], tasks: [taskB], defaultListID: listB.id.uuidString)
    try await repository.save(storeB)

    let loaded = try await repository.loadAll()
    #expect(loaded.lists.map(\.id) == [listB.id])
    #expect(loaded.tasks.map(\.id) == [taskB.id])
    #expect(loaded.defaultListID == listB.id.uuidString)
  }

  @Test func allLocalTaskFieldsSurviveRoundTrip() async throws {
    let repository = try SwiftDataLocalTaskRepository.makeInMemory()
    let listID = UUID()
    let created = Date(timeIntervalSinceReferenceDate: 0)
    let due = Date(timeIntervalSinceReferenceDate: 100)
    let scheduled = Date(timeIntervalSinceReferenceDate: 200)
    let start = Date(timeIntervalSinceReferenceDate: 300)
    let completed = Date(timeIntervalSinceReferenceDate: 400)
    let task = makeTask(
      title: "Full", notes: "Some notes", format: .plainText, priority: .highest,
      dueDate: due, scheduledDate: scheduled, startDate: start, listID: listID,
      isCompleted: true, completedAt: completed, createdAt: created)
    try await repository.save(LocalStore(lists: [], tasks: [task], defaultListID: nil))

    let loaded = try await repository.loadAll()
    let roundTripped = try #require(loaded.tasks.first)
    #expect(roundTripped.id == task.id)
    #expect(roundTripped.title == "Full")
    #expect(roundTripped.notes == "Some notes")
    #expect(roundTripped.format == .plainText)
    #expect(roundTripped.priority == .highest)
    #expect(roundTripped.dueDate == due)
    #expect(roundTripped.scheduledDate == scheduled)
    #expect(roundTripped.startDate == start)
    #expect(roundTripped.listID == listID)
    #expect(roundTripped.isCompleted == true)
    #expect(roundTripped.completedAt == completed)
    #expect(roundTripped.createdAt == created)
  }
}
