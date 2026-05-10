//
//  URLSchemeProviderTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

@MainActor
struct URLSchemeProviderTests {

  // MARK: - Helpers

  private func makeTempURL() -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("json")
  }

  private func makeTask(title: String = "Task") -> TaskItem {
    TaskItem(
      id: TaskRef(providerID: URLSchemeProvider.providerID, nativeID: UUID().uuidString),
      title: title,
      notes: nil,
      format: .plainText,
      priority: .none,
      dueDate: nil,
      scheduledDate: nil,
      startDate: nil,
      list: nil,
      section: nil,
      sourceURL: nil
    )
  }

  // MARK: - Basic operations

  @Test func addPrependsTask() async throws {
    let provider = URLSchemeProvider(persistenceURL: makeTempURL())
    provider.add(makeTask(title: "First"))
    provider.add(makeTask(title: "Second"))
    let items = try await provider.tasks(in: nil)
    #expect(items.first?.title == "Second")
  }

  @Test func addDeduplicatesByNativeID() async throws {
    let provider = URLSchemeProvider(persistenceURL: makeTempURL())
    let task = makeTask(title: "Deduped")
    provider.add(task)
    provider.add(task)
    let items = try await provider.tasks(in: nil)
    #expect(items.count == 1)
  }

  @Test func addMovesDuplicateToFront() async throws {
    let provider = URLSchemeProvider(persistenceURL: makeTempURL())
    let task = makeTask(title: "Move Me")
    provider.add(makeTask(title: "Other"))
    provider.add(task)
    provider.add(task)  // re-add same task
    let items = try await provider.tasks(in: nil)
    #expect(items.first?.id == task.id)
  }

  @Test func addCapsAtMaxRecents() async throws {
    let provider = URLSchemeProvider(persistenceURL: makeTempURL())
    for index in 0..<URLSchemeProvider.maxRecents + 3 {
      provider.add(makeTask(title: "Task \(index)"))
    }
    let items = try await provider.tasks(in: nil)
    #expect(items.count == URLSchemeProvider.maxRecents)
  }

  @Test func listsReturnsEmpty() async throws {
    let provider = URLSchemeProvider(persistenceURL: makeTempURL())
    let lists = try await provider.lists()
    #expect(lists.isEmpty)
  }

  // MARK: - Persistence

  @Test func persistsAndReloads() async throws {
    let url = makeTempURL()
    let provider = URLSchemeProvider(persistenceURL: url)
    provider.add(makeTask(title: "Persistent Task"))

    let reloaded = URLSchemeProvider(persistenceURL: url)
    let items = try await reloaded.tasks(in: nil)
    #expect(items.first?.title == "Persistent Task")
  }

  @Test func reloadedCountMatchesOriginal() async throws {
    let url = makeTempURL()
    let provider = URLSchemeProvider(persistenceURL: url)
    provider.add(makeTask(title: "A"))
    provider.add(makeTask(title: "B"))
    provider.add(makeTask(title: "C"))

    let reloaded = URLSchemeProvider(persistenceURL: url)
    let items = try await reloaded.tasks(in: nil)
    #expect(items.count == 3)
  }

  @Test func emptyProviderDoesNotCrashOnReload() async throws {
    let url = makeTempURL()
    let provider = URLSchemeProvider(persistenceURL: url)
    let items = try await provider.tasks(in: nil)
    #expect(items.isEmpty)
  }
}
