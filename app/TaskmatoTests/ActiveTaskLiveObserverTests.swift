//
//  ActiveTaskLiveObserverTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

@MainActor
private final class LiveObservationStubProvider: TaskProvider {
  let id: ProviderID = "live"
  let displayName: String = "Live"
  let icon: String = "dot.radiowaves.left.and.right"
  let entitlement: ProviderEntitlement = .free
  var stubbedTasks: [TaskItem] = []
  private var continuations: [AsyncStream<[TaskItem]>.Continuation] = []

  func authorize() async throws {}
  func lists() async throws -> [TaskList] {
    [TaskList(id: "default", providerID: id, name: "Default")]
  }
  func tasks(in _: TaskList?) async throws -> [TaskItem] { stubbedTasks }
  func observe() -> AsyncStream<[TaskItem]>? {
    let (stream, continuation) = AsyncStream<[TaskItem]>.makeStream()
    continuations.append(continuation)
    return stream
  }
  func emit() {
    for continuation in continuations {
      continuation.yield(stubbedTasks)
    }
  }
}

@MainActor
private func makeLiveTask(
  providerID: ProviderID = "live", nativeID: String = "task-1", title: String = "Live task"
) -> TaskItem {
  TaskItem(
    id: TaskRef(providerID: providerID, nativeID: nativeID),
    title: title, notes: nil, format: .plainText, priority: .none,
    list: TaskList(id: "default", providerID: providerID, name: "Default")
  )
}

@Suite("ActiveTaskLiveObserver")
@MainActor
struct ActiveTaskLiveObserverTests {

  @Test func providerPushReconcilesActiveTask() async {
    let settingsStore = SettingsStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
    let provider = LiveObservationStubProvider()
    let registry = ProviderRegistry(store: settingsStore)
    registry.register(provider)
    registry.enable(provider)
    registry.setLists(
      [TaskList(id: "default", providerID: provider.id, name: "Default")],
      forProviderID: provider.id
    )
    let activeTaskStore = ActiveTaskStore(store: settingsStore)
    activeTaskStore.track(makeLiveTask(providerID: provider.id))
    let reconciler = ActiveTaskReconciler(
      registry: registry, activeTaskStore: activeTaskStore, engine: SessionEngine(),
      attribution: FocusAttribution(), errorPresenter: ErrorPresenter())
    let observer = ActiveTaskLiveObserver(registry: registry, reconciler: reconciler)
    observer.start()

    provider.stubbedTasks = []
    provider.emit()
    for _ in 0..<20 { await Task.yield() }

    #expect(activeTaskStore.activeTask == nil)
    observer.stop()
  }
}
