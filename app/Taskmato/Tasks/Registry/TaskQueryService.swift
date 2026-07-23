//
//  TaskQueryService.swift
//  Taskmato
//

import Foundation

/// A per-provider error returned alongside tasks when a provider fetch fails.
typealias ProviderFetchError = (providerID: String, error: any Error)

/// Fans out task queries across the enabled providers in a ``ProviderRegistry`` and orders the result.
///
/// This is the query concern extracted from the former `ProviderRegistry` façade. It reads the
/// registry's provider set, enabled state, and list cache, performs the fetch (single-list or
/// cross-provider fan-out), applies the query filter, and delegates ordering to a ``TaskSorter``.
@MainActor
final class TaskQueryService {

  /// Held strongly: the registry references nothing here (its only back-path is a
  /// `[weak]` `onProviderStateChanged` closure to `SelectionStore`), so there is no
  /// cycle, and a strong hold keeps the service usable regardless of who else retains
  /// the registry — matching `SelectionStore`.
  private let registry: ProviderRegistry
  private let sorter: TaskSorter

  /// - Parameters:
  ///   - registry: The registry supplying providers, enabled state, and the list cache.
  ///   - sorter: The sorter used to order query results.
  init(registry: ProviderRegistry, sorter: TaskSorter) {
    self.registry = registry
    self.sorter = sorter
  }

  /// Returns tasks described by the given query, sorted by the specified field and direction.
  ///
  /// - `.singleList`: returns tasks from the named list, preserving provider section order.
  ///   Uses the registry's `providerLists` cache to resolve the `TaskList`; falls back to a
  ///   live fetch if the cache is not yet populated.
  /// - `.crossProvider`: fans out across all enabled providers, applies the optional filter,
  ///   and sorts results globally (section boundaries are not preserved).
  ///
  /// - Parameters:
  ///   - query: Describes the scope and optional filter for the fetch.
  ///   - sortBy: The field to sort by.
  ///   - direction: The sort direction.
  /// - Returns: Matched tasks and any per-provider errors that occurred.
  func tasks(
    query: TaskQuery,
    sortBy field: TaskSortField,
    direction: TaskSortDirection
  ) async -> (tasks: [TaskItem], errors: [ProviderFetchError]) {
    let active = registry.providers.filter { registry.isEnabled($0.id) }

    switch query {
    case .singleList(let selectedList):
      guard
        let provider = registry.providers.first(where: { $0.id == selectedList.providerID }),
        registry.isEnabled(provider.id)
      else {
        return (tasks: [], errors: [])
      }
      let available: [TaskList]
      if let cached = registry.providerLists[selectedList.providerID] {
        available = cached
      } else {
        available = (try? await provider.lists()) ?? []
      }
      guard let list = available.first(where: { $0.id == selectedList.listID }) else {
        return (tasks: [], errors: [])
      }
      let items = (try? await provider.tasks(in: list)) ?? []
      return (tasks: sorter.sorted(items, by: field, direction: direction), errors: [])

    case .crossProvider(let filter):
      let (all, errors) = await globalFanOut(providers: active)
      let filtered: [TaskItem]
      switch filter {
      case nil:
        filtered = all
      case .dueUpToToday:
        filtered = all.filter { item in
          guard let due = item.dueDate else { return false }
          return due <= Calendar.current.endOfToday
        }
      case .titleContains(let titleQuery):
        filtered = all.filter { $0.title.localizedCaseInsensitiveContains(titleQuery) }
      }
      return (
        tasks: sorter.sorted(filtered, by: field, direction: direction, preserveSections: false),
        errors: errors
      )
    }
  }

  /// Returns completed tasks described by the given query, sorted by the specified field and direction.
  ///
  /// Fans out `completedTasks()` across all enabled ``ClosableTaskProvider``s, applies the same
  /// filter logic as ``tasks(query:sortBy:direction:)``, and sorts the flat result globally.
  ///
  /// - Parameters:
  ///   - query: Describes the scope and optional filter for the fetch.
  ///   - sortBy: The field to sort by.
  ///   - direction: The sort direction.
  /// - Returns: Matched completed tasks and any per-provider errors that occurred.
  func completedTasks(
    query: TaskQuery,
    sortBy field: TaskSortField,
    direction: TaskSortDirection
  ) async -> (tasks: [TaskItem], errors: [ProviderFetchError]) {
    var all: [TaskItem] = []
    var providerErrors: [ProviderFetchError] = []

    await withTaskGroup(of: (items: [TaskItem], fetchError: ProviderFetchError?).self) { group in
      for provider in registry.providers where registry.isEnabled(provider.id) {
        guard let closable = provider as? (any ClosableTaskProvider) else { continue }
        let providerID = provider.id
        group.addTask {
          do {
            let items = try await closable.completedTasks()
            return (items: items, fetchError: nil)
          } catch {
            return (items: [], fetchError: (providerID: providerID, error: error))
          }
        }
      }
      for await result in group {
        all.append(contentsOf: result.items)
        if let fetchError = result.fetchError {
          providerErrors.append(fetchError)
        }
      }
    }

    let filtered: [TaskItem]
    switch query {
    case .singleList(let selectedList):
      filtered = all.filter { $0.list?.id == selectedList.listID }
    case .crossProvider(let filter):
      switch filter {
      case nil:
        filtered = all
      case .dueUpToToday:
        let startOfToday = Calendar.current.startOfDay(for: Date())
        filtered = all.filter { ($0.completedAt ?? .distantPast) >= startOfToday }
      case .titleContains(let titleQuery):
        filtered = all.filter { $0.title.localizedCaseInsensitiveContains(titleQuery) }
      }
    }

    return (
      tasks: sorter.sorted(filtered, by: field, direction: direction, preserveSections: false),
      errors: providerErrors
    )
  }

  private func globalFanOut(providers: [any TaskProvider]) async -> (
    [TaskItem], [ProviderFetchError]
  ) {
    var merged: [TaskItem] = []
    var providerErrors: [ProviderFetchError] = []

    await withTaskGroup(of: (items: [TaskItem], fetchError: ProviderFetchError?).self) { group in
      for provider in providers {
        let providerID = provider.id
        group.addTask {
          do {
            let allLists = try await provider.lists()
            let items: [TaskItem]
            if allLists.isEmpty {
              items = try await provider.tasks(in: nil)
            } else {
              var scoped: [TaskItem] = []
              for list in allLists {
                scoped += try await provider.tasks(in: list)
              }
              items = scoped
            }
            return (items: items, fetchError: nil)
          } catch {
            return (items: [], fetchError: (providerID: providerID, error: error))
          }
        }
      }
      for await result in group {
        merged.append(contentsOf: result.items)
        if let fetchError = result.fetchError {
          providerErrors.append(fetchError)
        }
      }
    }

    return (merged, providerErrors)
  }
}

// MARK: - Calendar helpers

extension Calendar {
  /// The last instant of today, DST-safe.
  ///
  /// Advances `startOfDay` by one calendar day and subtracts one second, rather than
  /// adding a fixed 86 400-second interval, so the result is correct on DST transition
  /// days when a civil day is 23 or 25 hours long.
  fileprivate var endOfToday: Date {
    let tomorrow = date(byAdding: .day, value: 1, to: startOfDay(for: Date())) ?? Date()
    return tomorrow.addingTimeInterval(-1)
  }
}
