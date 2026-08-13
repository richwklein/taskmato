//
//  TaskProviderLinkTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

// MARK: - Fakes

private final class StubProvider: TaskProvider {
  let id: ProviderID
  let displayName: String
  let icon: String
  let entitlement: ProviderEntitlement = .free

  init(id: ProviderID, displayName: String, icon: String) {
    self.id = id
    self.displayName = displayName
    self.icon = icon
  }

  func authorize() async throws {}
  func lists() async throws -> [TaskList] { [] }
  func tasks(in _: TaskList?) async throws -> [TaskItem] { [] }
  func observe() -> AsyncStream<[TaskItem]>? { nil }
}

// MARK: - Helpers

/// Builds a minimal task for a given provider ID and optional `sourceURL`.
private func makeTask(providerID: ProviderID, sourceURL: URL? = nil) -> TaskItem {
  TaskItem(
    id: TaskRef(providerID: providerID, nativeID: UUID().uuidString),
    title: "Sample task",
    notes: nil,
    format: .plainText,
    priority: .none,
    sourceURL: sourceURL
  )
}

// MARK: - Tests

@Suite("TaskProviderLink")
struct TaskProviderLinkTests {

  private static let obsidianURL = URL(string: "obsidian://open?vault=Notes&file=Task")!

  // MARK: Value init

  @Test func nilWhenTaskHasNoSourceURL() {
    let task = makeTask(providerID: "local")
    let link = TaskProviderLink(task: task, providerName: "Obsidian", icon: "book.closed")
    #expect(link == nil)
  }

  @Test func nilWhenProviderNameIsUnknown() {
    let task = makeTask(providerID: "obsidian", sourceURL: Self.obsidianURL)
    let link = TaskProviderLink(task: task, providerName: nil, icon: "book.closed")
    #expect(link == nil)
  }

  @Test func nilWhenProviderIconIsUnknown() {
    let task = makeTask(providerID: "obsidian", sourceURL: Self.obsidianURL)
    let link = TaskProviderLink(task: task, providerName: "Obsidian", icon: nil)
    #expect(link == nil)
  }

  @Test func resolvesURLProviderNameAndIcon() {
    let task = makeTask(providerID: "obsidian", sourceURL: Self.obsidianURL)
    let link = TaskProviderLink(task: task, providerName: "Obsidian", icon: "book.closed")
    #expect(link?.url == Self.obsidianURL)
    #expect(link?.providerName == "Obsidian")
    #expect(link?.icon == "book.closed")
  }

  @Test func titleAndLabelReflectProviderName() {
    let task = makeTask(providerID: "obsidian", sourceURL: Self.obsidianURL)
    let link = TaskProviderLink(task: task, providerName: "Obsidian", icon: "book.closed")
    #expect(link?.title == "Open in Obsidian")
    #expect(link?.label.systemImage == "book.closed")
  }

  // MARK: Registry-backed init

  @MainActor
  private func makeRegistry() -> ProviderRegistry {
    ProviderRegistry(store: SettingsStore(defaults: UserDefaults(suiteName: UUID().uuidString)!))
  }

  @MainActor
  @Test func registryResolvesLinkForRegisteredProvider() {
    let registry = makeRegistry()
    registry.register(StubProvider(id: "obsidian", displayName: "Obsidian", icon: "book.closed"))
    let task = makeTask(providerID: "obsidian", sourceURL: Self.obsidianURL)

    let link = TaskProviderLink(task: task, registry: registry)

    #expect(link?.url == Self.obsidianURL)
    #expect(link?.title == "Open in Obsidian")
  }

  @MainActor
  @Test func registryReturnsNilForUnregisteredProvider() {
    let registry = makeRegistry()
    let task = makeTask(providerID: "obsidian", sourceURL: Self.obsidianURL)

    let link = TaskProviderLink(task: task, registry: registry)

    #expect(link == nil)
  }
}
