//
//  ActiveTaskLiveObserver.swift
//  Taskmato
//

import AppKit
import Foundation

/// Maintains app-lifetime live-update subscriptions for active-task reconciliation.
///
/// Providers expose live changes as independent ``TaskProvider/observe()`` streams. The Tasks tab
/// owns view-scoped subscriptions for refreshing its list, while this service owns one
/// composition-root subscription per enabled provider so Timer surfaces reconcile when the source
/// task is deleted or completed elsewhere. Subscriptions are reconciled against the registry
/// instead of created once at launch, so a provider enabled later is observed too.
@MainActor
final class ActiveTaskLiveObserver {

  private let registry: ProviderRegistry
  private weak var reconciler: ActiveTaskReconciler?
  private var providerTasks: [ProviderID: Task<Void, Never>] = [:]
  private var terminationObserver: NSObjectProtocol?

  /// - Parameters:
  ///   - registry: Source of enabled providers to observe.
  ///   - reconciler: Service invoked whenever a provider emits a live change.
  init(registry: ProviderRegistry, reconciler: ActiveTaskReconciler) {
    self.registry = registry
    self.reconciler = reconciler
  }

  /// Starts observing enabled providers and wires process-termination cleanup.
  func start() {
    reconcileSubscriptions()
    guard terminationObserver == nil else { return }
    terminationObserver = NotificationCenter.default.addObserver(
      forName: NSApplication.willTerminateNotification, object: nil, queue: .main
    ) { [weak self] _ in
      Task { @MainActor [weak self] in
        self?.stop()
      }
    }
  }

  /// Reconciles live subscriptions with the registry's current enabled-provider set.
  func reconcileSubscriptions() {
    let enabledIDs = Set(registry.providers.filter { registry.isEnabled($0.id) }.map(\.id))
    for (providerID, task) in providerTasks where !enabledIDs.contains(providerID) {
      task.cancel()
      providerTasks[providerID] = nil
    }

    for provider in registry.providers where registry.isEnabled(provider.id) {
      guard providerTasks[provider.id] == nil, let stream = provider.observe() else { continue }
      providerTasks[provider.id] = Task { [weak reconciler] in
        for await _ in stream {
          await reconciler?.reconcile()
        }
      }
    }
  }

  /// Cancels every live subscription and unregisters the process-termination observer.
  func stop() {
    for task in providerTasks.values {
      task.cancel()
    }
    providerTasks.removeAll()
    if let terminationObserver {
      NotificationCenter.default.removeObserver(terminationObserver)
      self.terminationObserver = nil
    }
  }
}
