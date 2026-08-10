//
//  URLSchemeHandler.swift
//  Taskmato
//

import Foundation
import Observation
import os

/// Parameters extracted from a `taskmato://start` URL that describe an ad-hoc task.
struct AdHocTaskParams {
  /// The raw title from the URL.
  let title: String
  /// Resolved priority, defaulting to `.none` if the param was absent or unrecognised.
  let priority: TaskPriority
  /// Parsed due date, or `nil` if no `due` param was supplied.
  let dueDate: Date?
  /// Whether `dueDate` carries a meaningful time-of-day (the `due` param included one), or is
  /// date-only.
  let dueDateIncludesTime: Bool
  /// Raw list name from the URL, or `nil` if the param was absent.
  let listName: String?
  /// Raw section (sub-grouping within the list) from the URL, or `nil` if the param was absent.
  ///
  /// Passed straight through to ``TaskDraft/section`` — unlike `listName`, no name-to-ID
  /// resolution is needed since a section is already a plain string.
  let section: String?
  /// Raw provider ID from the URL, or `nil` if the param was absent.
  ///
  /// When set and the named provider is an enabled ``WritableTaskProvider``, ad-hoc task
  /// creation targets that provider regardless of the default-provider setting.
  let providerID: String?
}

/// Parses and dispatches `taskmato://` deep links to select a task and, when auto-start is
/// enabled, start a focus session.
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

  /// Traces deep-link handling so a `taskmato://` invocation that reaches the handler but
  /// resolves to nothing can be told apart from one that never arrives (issue #460).
  private let logger = Logger(subsystem: "com.taskmato", category: "URLScheme")

  private let registry: ProviderRegistry
  private let queryService: TaskQueryService
  private let selectionStore: TaskSelectionStore
  private let engine: SessionEngine
  private let settings: AppSettings
  private let nav: MainNavigation
  private let errorPresenter: ErrorPresenter
  private let destinationResolver: TaskDestinationResolver

  init(
    registry: ProviderRegistry,
    queryService: TaskQueryService,
    selectionStore: TaskSelectionStore,
    engine: SessionEngine,
    settings: AppSettings,
    nav: MainNavigation,
    errorPresenter: ErrorPresenter,
    destinationResolver: TaskDestinationResolver
  ) {
    self.registry = registry
    self.queryService = queryService
    self.selectionStore = selectionStore
    self.engine = engine
    self.settings = settings
    self.nav = nav
    self.errorPresenter = errorPresenter
    self.destinationResolver = destinationResolver
  }

  /// Handles the given URL, selecting the resolved task and starting a focus session if
  /// the engine is idle and auto-start is enabled.
  func handle(_ url: URL) async {
    guard url.scheme?.lowercased() == "taskmato",
      url.host?.lowercased() == "start",
      let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    else {
      let scheme = url.scheme ?? "nil"
      let host = url.host ?? "nil"
      logger.error(
        "handle() rejected by guard: scheme=\(scheme, privacy: .public) host=\(host, privacy: .public)"
      )
      return
    }

    let params = queryParams(from: components)
    guard let task = await resolve(params: params) else {
      logger.log("handle() resolved no task (disambiguation pending or ad-hoc failed); no session")
      return
    }

    logger.log("handle() resolved task; selecting and routing to Timer")
    selectionStore.select(task)
    nav.showTimerInMainWindow()
    let engineIdle = engine.state == .idle
    let autoStart = settings.autoStartNextPhase
    if engineIdle, autoStart {
      engine.applyDurations(from: settings)
      engine.start(phase: .focus)
      logger.log("handle() started focus session")
    } else {
      logger.log(
        "handle() no session: engineIdle=\(engineIdle, privacy: .public) autoStart=\(autoStart, privacy: .public)"
      )
    }
  }

  /// Creates an ad-hoc task from the given params.
  ///
  /// Provider resolution order:
  /// 1. `adHocParams.providerID` (URL `provider=` param) if set and the named provider is
  ///    an enabled ``WritableTaskProvider``.
  /// 2. ``AppSettings/defaultWritableProviderID`` if set and the named provider is enabled.
  /// 3. ``ProviderRegistry/firstEnabledWritableProvider`` — the first enabled writable provider
  ///    in registration order.
  ///
  /// Returns `nil` after surfacing an error on the window-root banner when no enabled writable
  /// provider is available or the write fails; the caller then starts no session.
  func makeAdHocTask(from adHocParams: AdHocTaskParams) async -> TaskItem? {
    let destination: TaskDestination
    do {
      destination = try await destinationResolver.resolve(
        providerID: adHocParams.providerID.map(ProviderID.init(_:)),
        listName: adHocParams.listName)
    } catch {
      errorPresenter.present(title: AppLabels.Error.adhocCreateFailed, error: error)
      return nil
    }

    var draft = TaskDraft()
    draft.title = adHocParams.title
    draft.priority = adHocParams.priority
    draft.dueDate = adHocParams.dueDate
    draft.dueDateIncludesTime = adHocParams.dueDateIncludesTime
    draft.section = adHocParams.section
    draft.listID = destination.listID
    do {
      return try await destination.provider.addTask(draft)
    } catch {
      errorPresenter.present(title: AppLabels.Error.adhocCreateFailed, error: error)
      return nil
    }
  }

  // MARK: - Resolution

  private func resolve(params: [String: String]) async -> TaskItem? {
    let providerID = params["provider"]
    let nativeID = params["id"]
    let title = params["title"]

    // 1. Exact lookup by stable ID within a named provider
    if let providerID, let nativeID {
      if let task = await lookupByID(nativeID: nativeID, providerID: ProviderID(providerID)) {
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
      if let task = await lookupByTitle(title, providerID: ProviderID(providerID)) {
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
        // Open the main window so the relocated disambiguation dialog has a surface to
        // present on (design doc 0008, D5); the success path opens it via the selection.
        nav.openMainWindow()
        return nil
      }
      return await makeAdHocTask(from: buildAdHocParams(from: params, title: title))
    }

    return nil
  }

  private func lookupByID(nativeID: String, providerID: ProviderID) async -> TaskItem? {
    guard let provider = registry.providers.first(where: { $0.id == providerID }),
      registry.isEnabled(provider.id)
    else { return nil }
    let all = (try? await provider.tasks(in: nil)) ?? []
    let ref = TaskRef(providerID: providerID, nativeID: nativeID)
    return provider.resolve(ref, among: all)
  }

  private func crossProviderIDLookup(nativeID: String) async -> TaskItem? {
    for provider in registry.providers where registry.isEnabled(provider.id) {
      let all = (try? await provider.tasks(in: nil)) ?? []
      let ref = TaskRef(providerID: provider.id, nativeID: nativeID)
      if let found = provider.resolve(ref, among: all) {
        return found
      }
    }
    return nil
  }

  private func lookupByTitle(_ title: String, providerID: ProviderID) async -> TaskItem? {
    guard let provider = registry.providers.first(where: { $0.id == providerID }),
      registry.isEnabled(provider.id)
    else { return nil }
    let all = (try? await provider.tasks(in: nil)) ?? []
    return all.first { $0.title.localizedCaseInsensitiveContains(title) }
  }

  private func crossProviderTitleSearch(title: String) async -> [TaskItem] {
    let (tasks, _) = await queryService.tasks(
      query: .crossProvider(filter: .titleContains(title)), sortBy: .title, direction: .ascending)
    return tasks
  }

  private func buildAdHocParams(from params: [String: String], title: String) -> AdHocTaskParams {
    let due = params["due"].flatMap(parseDueDate(_:))
    return AdHocTaskParams(
      title: title,
      priority: params["priority"].flatMap(TaskPriority.init(urlParam:)) ?? .none,
      dueDate: due?.date,
      dueDateIncludesTime: due?.includesTime ?? false,
      listName: params["list"],
      section: params["section"],
      providerID: params["provider"]
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

  /// Parses a `due` param of the form `YYYY-MM-DD` or `YYYY-MM-DD HH:MM` (the space arrives
  /// decoded from a `+` or `%20` in the URL query), returning the date plus whether a time was
  /// given. Built via `Calendar.current` rather than `ISO8601DateFormatter`, which parses
  /// date-only strings as UTC midnight — that lands on the *previous* local day west of UTC
  /// (e.g. `"2026-08-10"` became 2026-08-09 in a US timezone). Matches ``AddTaskView``'s
  /// date-only path, which builds the date the same way for the same reason.
  private func parseDueDate(_ string: String) -> (date: Date, includesTime: Bool)? {
    let parts = string.trimmingCharacters(in: .whitespaces).split(separator: " ", maxSplits: 1)
    guard var components = parts.first.flatMap(Self.dateComponents(_:)) else { return nil }
    guard parts.count == 2 else {
      return Calendar.current.date(from: components).map { ($0, false) }
    }
    guard let (hour, minute) = Self.timeComponents(String(parts[1])) else { return nil }
    components.hour = hour
    components.minute = minute
    return Calendar.current.date(from: components).map { ($0, true) }
  }

  /// Parses a `YYYY-MM-DD` substring into year/month/day `DateComponents`.
  private nonisolated static func dateComponents(_ substring: Substring) -> DateComponents? {
    let parts = substring.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 3 else { return nil }
    var components = DateComponents()
    components.year = parts[0]
    components.month = parts[1]
    components.day = parts[2]
    return components
  }

  /// Parses an `HH:MM` string into hour/minute.
  private nonisolated static func timeComponents(_ string: String) -> (hour: Int, minute: Int)? {
    let parts = string.split(separator: ":").compactMap { Int($0) }
    guard parts.count == 2 else { return nil }
    return (parts[0], parts[1])
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
