//
//  URLSchemeHandler.swift
//  Taskmato
//

import Foundation
import Observation

/// Parameters extracted from a `taskmato://start` URL that describe an ad-hoc task.
struct AdHocTaskParams {
  /// The raw title from the URL.
  let title: String
  /// Resolved priority, defaulting to `.none` if the param was absent or unrecognised.
  let priority: TaskPriority
  /// Parsed due date, or `nil` if no `due` param was supplied.
  let dueDate: Date?
  /// Raw list name from the URL, or `nil` if the param was absent.
  let listName: String?
}

/// Parses and dispatches `taskmato://` deep links to select a task and optionally start a session.
///
/// Resolution precedence for `taskmato://start`:
/// 1. `provider` + `id` — exact native-ID lookup within the named provider
/// 2. `id` only — cross-provider fan-out by native ID across all enabled providers
/// 3. `provider` + `title` — first case-insensitive title match within the named provider
/// 4. `title` only — cross-provider search; one match → select; two-or-more →
///    disambiguation dialog; zero matches → create a transient ad-hoc task and select it
@Observable
@MainActor
final class URLSchemeHandler {

  /// Tasks presented to the user when multiple title matches are found.
  ///
  /// Set to non-`nil` by ``handle(_:)`` when resolution is ambiguous; cleared once the user
  /// picks a task or taps Cancel in the confirmation dialog.
  var pendingDisambiguation: [TaskItem]?

  /// Saved params for the "Create new" button shown alongside disambiguation choices.
  var pendingAdHocParams: AdHocTaskParams?

  private let registry: TaskRegistry
  private let selectionStore: TaskSelectionStore
  private let engine: SessionEngine

  init(registry: TaskRegistry, selectionStore: TaskSelectionStore, engine: SessionEngine) {
    self.registry = registry
    self.selectionStore = selectionStore
    self.engine = engine
  }

  /// Handles the given URL, selecting the resolved task and starting a focus session if idle.
  func handle(_ url: URL) async {
    guard url.scheme?.lowercased() == "taskmato",
      url.host?.lowercased() == "start",
      let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    else { return }

    let params = queryParams(from: components)
    guard let task = await resolve(params: params) else { return }

    selectionStore.select(task)
    if case .idle = engine.state {
      engine.start(phase: .focus)
    }
  }

  /// Builds a transient ad-hoc ``TaskItem`` from the given params without persisting it to any provider.
  func makeAdHocTask(from adHocParams: AdHocTaskParams) -> TaskItem {
    let list = adHocParams.listName.map { name in
      TaskList(
        id: name.lowercased().replacingOccurrences(of: " ", with: "-"),
        providerID: "adhoc",
        name: name
      )
    }
    return TaskItem(
      id: TaskRef(providerID: "adhoc", nativeID: UUID().uuidString),
      title: adHocParams.title,
      notes: nil,
      format: .plainText,
      priority: adHocParams.priority,
      dueDate: adHocParams.dueDate,
      scheduledDate: nil,
      startDate: nil,
      list: list,
      section: nil,
      sourceURL: nil
    )
  }

  // MARK: - Resolution

  private func resolve(params: [String: String]) async -> TaskItem? {
    let providerID = params["provider"]
    let nativeID = params["id"]
    let title = params["title"]

    // 1. Exact lookup by stable ID within a named provider
    if let providerID, let nativeID {
      if let task = await lookupByID(nativeID: nativeID, providerID: providerID) {
        return task
      }
    }

    // 2. ID-only cross-provider fan-out (no provider specified)
    if providerID == nil, let nativeID {
      if let task = await crossProviderIDLookup(nativeID: nativeID) {
        return task
      }
    }

    // 3. Title match within a named provider
    if let providerID, let title {
      if let task = await lookupByTitle(title, providerID: providerID) {
        return task
      }
    }

    // 4. Cross-provider title search, then disambiguation or transient ad-hoc fallback
    if let title {
      let matches = await crossProviderTitleSearch(title: title)
      if matches.count == 1 {
        return matches[0]
      } else if matches.count > 1 {
        pendingDisambiguation = matches
        pendingAdHocParams = buildAdHocParams(from: params, title: title)
        return nil
      }
      return makeAdHocTask(from: buildAdHocParams(from: params, title: title))
    }

    return nil
  }

  private func lookupByID(nativeID: String, providerID: String) async -> TaskItem? {
    guard let provider = registry.providers.first(where: { $0.id == providerID })
    else { return nil }
    let all = (try? await provider.tasks(in: nil)) ?? []
    return all.first { $0.id.nativeID == nativeID }
  }

  private func crossProviderIDLookup(nativeID: String) async -> TaskItem? {
    for provider in registry.providers where registry.isEnabled(provider.id) {
      let all = (try? await provider.tasks(in: nil)) ?? []
      if let found = all.first(where: { $0.id.nativeID == nativeID }) {
        return found
      }
    }
    return nil
  }

  private func lookupByTitle(_ title: String, providerID: String) async -> TaskItem? {
    guard let provider = registry.providers.first(where: { $0.id == providerID })
    else { return nil }
    let all = (try? await provider.tasks(in: nil)) ?? []
    return all.first { $0.title.localizedCaseInsensitiveContains(title) }
  }

  private func crossProviderTitleSearch(title: String) async -> [TaskItem] {
    let (tasks, _) = await registry.tasks(matching: title)
    return tasks
  }

  private func buildAdHocParams(from params: [String: String], title: String) -> AdHocTaskParams {
    AdHocTaskParams(
      title: title,
      priority: params["priority"].flatMap(TaskPriority.init(urlParam:)) ?? .none,
      dueDate: params["due"].flatMap(parseDate(_:)),
      listName: params["list"]
    )
  }

  // MARK: - Helpers

  private func queryParams(from components: URLComponents) -> [String: String] {
    (components.queryItems ?? []).reduce(into: [:]) { dict, item in
      if let value = item.value, !value.isEmpty {
        // URLComponents does not decode '+' as space (RFC 3986); do it manually
        // for compatibility with form-encoded values emitted by the shell wrapper.
        dict[item.name] = value.replacingOccurrences(of: "+", with: " ")
      }
    }
  }

  private func parseDate(_ string: String) -> Date? {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
    return formatter.date(from: string)
  }
}

// MARK: - TaskPriority URL param parsing

extension TaskPriority {
  /// Initialises from a URL query param string (e.g. `"high"`, `"lowest"`).
  fileprivate init?(urlParam: String) {
    switch urlParam.lowercased() {
    case "lowest": self = .lowest
    case "low": self = .low
    case "medium": self = .medium
    case "high": self = .high
    case "highest": self = .highest
    default: return nil
    }
  }
}
