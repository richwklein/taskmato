//
//  DisambiguationMatchTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

// MARK: - Fakes

private final class StubTaskProvider: TaskProvider {
  let id: ProviderID
  let displayName: String
  let icon: String
  let tint: ProviderTint
  let entitlement: ProviderEntitlement = .free

  init(id: ProviderID, displayName: String, icon: String, tint: ProviderTint) {
    self.id = id
    self.displayName = displayName
    self.icon = icon
    self.tint = tint
  }

  nonisolated func authorize() async throws {}
  func lists() async throws -> [TaskList] { [] }
  func tasks(in list: TaskList?) async throws -> [TaskItem] { [] }
  func observe() -> AsyncStream<[TaskItem]>? { nil }
}

private func makeTask(title: String, providerID: ProviderID) -> TaskItem {
  TaskItem(
    id: TaskRef(providerID: providerID, nativeID: UUID().uuidString),
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

// MARK: - Tests

@MainActor
struct DisambiguationMatchTests {

  @Test func resolvesProviderDisplayValuesFromRegistry() {
    let defaults = UserDefaults(suiteName: UUID().uuidString)!
    let registry = ProviderRegistry(store: SettingsStore(defaults: defaults))
    let provider = StubTaskProvider(
      id: "obsidian", displayName: "Obsidian", icon: "note.text", tint: .purple)
    registry.register(provider)
    let task = makeTask(title: "Standup", providerID: "obsidian")

    let match = DisambiguationMatch(task: task, registry: registry)

    #expect(match.providerName == "Obsidian")
    #expect(match.icon == "note.text")
    #expect(match.title == "Standup")
    #expect(match.id == task.id)
  }

  @Test func fallsBackToNeutralPlaceholderWhenProviderIsUnresolved() {
    let defaults = UserDefaults(suiteName: UUID().uuidString)!
    let registry = ProviderRegistry(store: SettingsStore(defaults: defaults))
    let task = makeTask(title: "Standup", providerID: "unknown")

    let match = DisambiguationMatch(task: task, registry: registry)

    #expect(match.providerName == "Unknown provider")
    #expect(match.icon == "questionmark.circle")
  }
}
