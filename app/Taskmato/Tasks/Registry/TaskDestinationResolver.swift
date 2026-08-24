//
//  TaskDestinationResolver.swift
//  Taskmato
//

import Foundation

/// The provider and list selected for a newly created task.
struct TaskDestination {

  /// The enabled writable provider that will receive the task.
  let provider: any WritableTaskProvider

  /// The provider-local list ID that will receive the task.
  let listID: String
}

/// Errors raised when Taskmato cannot resolve a writable task destination.
enum TaskDestinationResolutionError: LocalizedError, Equatable {

  /// No enabled provider can create tasks.
  case noWritableProvider

  /// The selected provider has no currently available list.
  case noAvailableList(providerID: ProviderID, providerName: String)

  var errorDescription: String? {
    switch self {
    case .noWritableProvider:
      return "No writable task provider is enabled. Enable a provider before creating a task."
    case .noAvailableList(_, let providerName):
      return
        "\(providerName) has no available lists. Configure a list before creating a task, "
        + "or pass --list to choose one."
    }
  }
}

/// Resolves the provider and list for every app-created task.
@MainActor
final class TaskDestinationResolver {

  private let registry: ProviderRegistry
  private let settings: AppSettings

  /// - Parameters:
  ///   - registry: The registry supplying enabled providers and current sidebar context.
  ///   - settings: The settings supplying the preferred writable provider.
  init(registry: ProviderRegistry, settings: AppSettings) {
    self.registry = registry
    self.settings = settings
  }

  /// Returns the writable provider selected by the provider precedence rules.
  /// - Parameters:
  ///   - providerID: An optional explicitly requested provider.
  ///   - sidebarSelection: The current sidebar selection for interactive routes.
  /// - Returns: An enabled writable provider, or `nil` when none is available.
  func provider(
    providerID: ProviderID? = nil, sidebarSelection: SidebarSelection? = nil
  ) -> (any WritableTaskProvider)? {
    resolveProvider(providerID: providerID, sidebarSelection: sidebarSelection)
  }

  /// Resolves a destination using the shared provider and list precedence rules.
  ///
  /// An invalid explicit provider falls through to the interactive sidebar context, the
  /// settings preference, and provider order. An explicit list ID is strict and must still
  /// exist; an unmatched list name is treated as absent so URL and CLI callers retain the
  /// approved default-list fallback.
  /// - Parameters:
  ///   - providerID: An optional provider requested by a URL or other route.
  ///   - listID: An optional already-resolved list ID from a UI action.
  ///   - listName: An optional human-readable list name from a URL or CLI invocation.
  ///   - sidebarSelection: The current sidebar selection for interactive routes.
  /// - Returns: A provider plus a currently available list ID.
  /// - Throws: ``TaskDestinationResolutionError`` when no writable provider or list exists.
  func resolve(
    providerID: ProviderID? = nil,
    listID: String? = nil,
    listName: String? = nil,
    sidebarSelection: SidebarSelection? = nil
  ) async throws -> TaskDestination {
    let provider = resolveProvider(providerID: providerID, sidebarSelection: sidebarSelection)
    guard let provider else {
      throw TaskDestinationResolutionError.noWritableProvider
    }

    let lists = try await provider.lists()
    let namedListID = listName.flatMap { name in
      lists.first { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }?.id
    }

    if let listID {
      guard lists.contains(where: { $0.id == listID }) else {
        throw TaskDestinationResolutionError.noAvailableList(
          providerID: provider.id, providerName: provider.displayName)
      }
      return TaskDestination(provider: provider, listID: listID)
    }

    if let namedListID {
      return TaskDestination(provider: provider, listID: namedListID)
    }

    if let sidebarListID = sidebarSelection?.listID(matching: provider.id) {
      if lists.contains(where: { $0.id == sidebarListID }) {
        return TaskDestination(provider: provider, listID: sidebarListID)
      }
    }

    guard
      let resolvedListID = DefaultListResolver.resolve(
        among: lists, storedDefault: provider.defaultListID)
    else {
      throw TaskDestinationResolutionError.noAvailableList(
        providerID: provider.id, providerName: provider.displayName)
    }
    return TaskDestination(provider: provider, listID: resolvedListID)
  }

  private func resolveProvider(
    providerID: ProviderID?, sidebarSelection: SidebarSelection?
  ) -> (any WritableTaskProvider)? {
    if let providerID, let provider = registry.enabledWritableProvider(id: providerID) {
      return provider
    }

    if case .list(let selectedList) = sidebarSelection {
      if let provider = registry.enabledWritableProvider(id: selectedList.providerID) {
        return provider
      }
    }

    return registry.resolveDefaultWritableProvider(preferredID: settings.defaultWritableProviderID)
  }
}
