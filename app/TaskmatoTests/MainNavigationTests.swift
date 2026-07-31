//
//  MainNavigationTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

// MARK: - Fakes

private final class NavStubProvider: TaskProvider {
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

// MARK: - Tests

@Suite("MainNavigation")
@MainActor
struct MainNavigationTests {

  /// The wired navigation model and its collaborators over one `UserDefaults` suite.
  private struct NavContext {
    let registry: ProviderRegistry
    let store: SelectionStore
    let statsViewModel: StatsViewModel
    let nav: MainNavigation
  }

  /// Builds a navigation model and its selection store over shared `defaults`, wiring
  /// `onProviderStateChanged` exactly as the composition root does (validate, then reconcile).
  private func makeNav(defaults: UserDefaults) -> NavContext {
    let settings = SettingsStore(defaults: defaults)
    let registry = ProviderRegistry(store: settings)
    let store = SelectionStore(registry: registry, store: settings)
    let statsViewModel = StatsViewModel.preview
    let nav = MainNavigation(
      settings: AppSettings(store: settings), selectionStore: store,
      statsViewModel: statsViewModel, store: settings)
    registry.onProviderStateChanged = { [weak store, weak nav] in
      store?.validateSelection()
      nav?.reconcileTaskScope()
    }
    return NavContext(registry: registry, store: store, statsViewModel: statsViewModel, nav: nav)
  }

  // MARK: - Defaults

  @Test func destinationDefaultsToTodayOnFirstLaunch() {
    let context = makeNav(defaults: UserDefaults(suiteName: UUID().uuidString)!)
    #expect(context.nav.destination == .today)
  }

  // MARK: - Round-trip

  @Test func timerDestinationRoundTripsAcrossInstances() {
    let defaults = UserDefaults(suiteName: UUID().uuidString)!
    makeNav(defaults: defaults).nav.destination = .timer
    #expect(makeNav(defaults: defaults).nav.destination == .timer)
  }

  @Test func statsDestinationRoundTripsWithScope() {
    let defaults = UserDefaults(suiteName: UUID().uuidString)!
    makeNav(defaults: defaults).nav.destination = .stats(.thisMonth)

    let restored = makeNav(defaults: defaults)
    #expect(restored.nav.destination == .stats(.thisMonth))
    #expect(restored.statsViewModel.scope == .thisMonth)
  }

  // MARK: - Reconcile

  @Test func vanishedListReconcilesDestinationToToday() {
    let defaults = UserDefaults(suiteName: UUID().uuidString)!
    let context = makeNav(defaults: defaults)
    let registry = context.registry
    let nav = context.nav
    let provider = NavStubProvider(id: "alpha")
    registry.register(provider)
    registry.enable(provider)

    nav.destination = .list(SelectedList(providerID: "alpha", listID: "old-list"))
    // The list no longer exists: an empty cache fires the hook, which validates the selection
    // to Today and reconciles the destination to match.
    registry.setLists([], forProviderID: "alpha")

    #expect(nav.destination == .today)
  }
}
