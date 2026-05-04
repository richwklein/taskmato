//
//  TaskProviderTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

// MARK: - Fakes

private final class FakeReadOnlyProvider: TaskProvider {
  let id = "fake-readonly"
  let displayName = "Fake Read-Only"
  let entitlement: ProviderEntitlement = .free

  func authorize() async throws {}
  func lists() async throws -> [TaskList] { [] }
  func tasks(in _: TaskList?) async throws -> [TaskItem] { [] }
  func observe() -> AsyncStream<[TaskItem]>? { nil }
}

private final class FakeMutableProvider: MutableTaskProvider {
  let id = "fake-mutable"
  let displayName = "Fake Mutable"
  let entitlement: ProviderEntitlement = .paid(productID: "com.taskmato.provider.fake")

  private(set) var completedRefs: [TaskRef] = []
  private(set) var reopenedRefs: [TaskRef] = []

  func authorize() async throws {}
  func lists() async throws -> [TaskList] { [] }
  func tasks(in _: TaskList?) async throws -> [TaskItem] { [] }
  func observe() -> AsyncStream<[TaskItem]>? { nil }

  func complete(_ ref: TaskRef) async throws { completedRefs.append(ref) }
  func reopen(_ ref: TaskRef) async throws { reopenedRefs.append(ref) }
}

// MARK: - Tests

@Suite("ProviderEntitlement")
struct ProviderEntitlementTests {

  @Test func freeIsEqualToFree() {
    #expect(ProviderEntitlement.free == .free)
  }

  @Test func paidMatchesSameProductID() {
    #expect(ProviderEntitlement.paid(productID: "com.x") == .paid(productID: "com.x"))
  }

  @Test func paidDiffersOnProductID() {
    #expect(ProviderEntitlement.paid(productID: "com.x") != .paid(productID: "com.y"))
  }

  @Test func freeDiffersFromPaid() {
    #expect(ProviderEntitlement.free != .paid(productID: "com.x"))
  }
}

@Suite("TaskProvider")
struct TaskProviderTests {

  @Test func readOnlyProviderProperties() {
    let provider = FakeReadOnlyProvider()
    #expect(provider.id == "fake-readonly")
    #expect(provider.displayName == "Fake Read-Only")
    #expect(provider.entitlement == .free)
  }

  @Test func readOnlyProviderObserveReturnsNil() {
    let provider = FakeReadOnlyProvider()
    #expect(provider.observe() == nil)
  }

  @Test func readOnlyProviderListsAndTasksReturnEmpty() async throws {
    let provider = FakeReadOnlyProvider()
    #expect(try await provider.lists().isEmpty)
    #expect(try await provider.tasks(in: nil).isEmpty)
  }

  @Test func mutableProviderIsPaid() {
    let provider = FakeMutableProvider()
    #expect(provider.entitlement == .paid(productID: "com.taskmato.provider.fake"))
  }

  @Test func mutableProviderTracksComplete() async throws {
    let provider = FakeMutableProvider()
    let ref = TaskRef(providerID: "fake-mutable", nativeID: "1")
    try await provider.complete(ref)
    #expect(provider.completedRefs == [ref])
    #expect(provider.reopenedRefs.isEmpty)
  }

  @Test func mutableProviderTracksReopen() async throws {
    let provider = FakeMutableProvider()
    let ref = TaskRef(providerID: "fake-mutable", nativeID: "1")
    try await provider.reopen(ref)
    #expect(provider.reopenedRefs == [ref])
    #expect(provider.completedRefs.isEmpty)
  }

  @Test func mutableProviderSatisfiesTaskProvider() {
    let provider: any TaskProvider = FakeMutableProvider()
    #expect(provider.id == "fake-mutable")
  }
}
