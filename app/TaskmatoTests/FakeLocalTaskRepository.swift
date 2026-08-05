//
//  FakeLocalTaskRepository.swift
//  TaskmatoTests
//

import Foundation

@testable import Taskmato

/// In-memory ``LocalTaskRepository`` whose ``loadAll()`` can be delayed.
///
/// The delay lets tests deterministically reproduce callers that race a provider's initial
/// load — e.g. a query issued immediately after construction, before the load completes —
/// rather than relying on real file I/O finishing fast enough to observe the race by luck.
actor FakeLocalTaskRepository: LocalTaskRepository {

  private let store: LocalStore
  private let loadDelayNanoseconds: UInt64

  init(
    store: LocalStore = LocalStore(lists: [], tasks: [], defaultListID: nil),
    loadDelayNanoseconds: UInt64 = 0
  ) {
    self.store = store
    self.loadDelayNanoseconds = loadDelayNanoseconds
  }

  func loadAll() async throws -> LocalStore {
    if loadDelayNanoseconds > 0 {
      try await Task.sleep(nanoseconds: loadDelayNanoseconds)
    }
    return store
  }

  func save(_ store: LocalStore) async throws {}
}
