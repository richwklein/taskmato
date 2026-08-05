//
//  LocalProviderSwiftDataTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

/// Smoke test exercising ``LocalProvider`` against a real ``SwiftDataLocalTaskRepository``
/// actor, the one path the direct-repository and direct-provider suites don't cover together.
@Suite("LocalProvider+SwiftData")
@MainActor
struct LocalProviderSwiftDataTests {

  @Test func addCompleteAndListRoundTripThroughSwiftData() async throws {
    let repository = try SwiftDataLocalTaskRepository.makeInMemory()
    let provider = LocalProvider(repository: repository)
    await provider.ready()

    var draft = TaskDraft()
    draft.title = "Ship the migration"
    try await provider.addTask(draft)

    let active = try await provider.tasks(in: nil)
    #expect(active.count == 1)
    #expect(active[0].title == "Ship the migration")

    try await provider.complete(active[0].id)

    let remaining = try await provider.tasks(in: nil)
    #expect(remaining.isEmpty)

    let completed = try await provider.completedTasks()
    #expect(completed.count == 1)
    #expect(completed[0].title == "Ship the migration")
  }
}
