//
//  ProviderRegistryEntitlementTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

// MARK: - Fakes

private final class StubFreeProvider: TaskProvider {
  let id: ProviderID
  let displayName: String
  let icon: String = "square"
  let entitlement: ProviderEntitlement = .free

  init(id: ProviderID) {
    self.id = id
    self.displayName = id.rawValue
  }

  func authorize() async throws {}
  func lists() async throws -> [TaskList] { [] }
  func tasks(in _: TaskList?) async throws -> [TaskItem] { [] }
  func observe() -> AsyncStream<[TaskItem]>? { nil }
}

private final class StubPaidProvider: TaskProvider {
  let id: ProviderID
  let displayName: String
  let icon: String = "square"
  let entitlement: ProviderEntitlement = .paid(productID: "com.taskmato.provider.fake")

  init(id: ProviderID) {
    self.id = id
    self.displayName = id.rawValue
  }

  func authorize() async throws {}
  func lists() async throws -> [TaskList] { [] }
  func tasks(in _: TaskList?) async throws -> [TaskItem] { [] }
  func observe() -> AsyncStream<[TaskItem]>? { nil }
}

// MARK: - Tests

@Suite("ProviderRegistry entitlement")
@MainActor
struct ProviderRegistryEntitlementTests {

  private func makeRegistry(entitlement: ProEntitlement) -> ProviderRegistry {
    let defaults = UserDefaults(suiteName: UUID().uuidString)!
    return ProviderRegistry(store: SettingsStore(defaults: defaults), entitlement: entitlement)
  }

  @Test func freeProviderEnablesWhileLocked() {
    let registry = makeRegistry(entitlement: ProEntitlement())
    let provider = StubFreeProvider(id: "free")
    registry.register(provider)
    registry.enable(provider)
    #expect(registry.isEnabled(provider.id))
  }

  @Test func registeredPaidProviderDoesNotEnableWhileLocked() {
    let registry = makeRegistry(entitlement: ProEntitlement())
    let provider = StubPaidProvider(id: "paid")
    registry.register(provider)
    registry.enable(provider)
    #expect(!registry.isEnabled(provider.id))
    #expect(!registry.enabledIDs.contains(provider.id))
  }

  @Test func registeredPaidProviderEnablesOnceUnlocked() {
    let entitlement = ProEntitlement()
    let registry = makeRegistry(entitlement: entitlement)
    let provider = StubPaidProvider(id: "paid")
    registry.register(provider)
    entitlement.update(isPro: true)
    registry.enable(provider)
    #expect(registry.isEnabled(provider.id))
    #expect(registry.enabledIDs.contains(provider.id))
  }

  @Test func unregisteredPaidProviderIsRefusedByEnable() {
    let entitlement = ProEntitlement()
    entitlement.update(isPro: true)
    let registry = makeRegistry(entitlement: entitlement)
    let provider = StubPaidProvider(id: "paid")
    // Never registered.
    registry.enable(provider)
    #expect(!registry.enabledIDs.contains(provider.id))
  }

  @Test func isUnlockedUnknownIDFailsClosed() {
    let registry = makeRegistry(entitlement: ProEntitlement())
    #expect(!registry.isUnlocked("unknown"))
  }

  @Test func relaunchWithLockedEntitlementDoesNotUnlockPersistedPreference() {
    let defaults = UserDefaults(suiteName: UUID().uuidString)!
    let store = SettingsStore(defaults: defaults)
    let paidID: ProviderID = "paid"
    store[SettingsStore.Keys.enabledProviderIDs] = [paidID]

    let entitlement = ProEntitlement()
    let registry = ProviderRegistry(store: store, entitlement: entitlement)
    let provider = StubPaidProvider(id: paidID)
    registry.register(provider)

    #expect(registry.enabledIDs.contains(paidID))
    #expect(!registry.isEnabled(paidID))

    entitlement.update(isPro: true)
    #expect(registry.isEnabled(paidID))
    // The persisted preference was never re-written by the entitlement flip.
    #expect(registry.enabledIDs.contains(paidID))
  }

  @Test func isEnabledUnregisteredIDStillReturnsTrueWhenPersisted() {
    let defaults = UserDefaults(suiteName: UUID().uuidString)!
    let store = SettingsStore(defaults: defaults)
    let unregisteredID: ProviderID = "ghost"
    store[SettingsStore.Keys.enabledProviderIDs] = [unregisteredID]

    let registry = ProviderRegistry(store: store, entitlement: ProEntitlement())
    #expect(registry.isEnabled(unregisteredID))
  }
}
