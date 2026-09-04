//
//  SessionPortabilityController.swift
//  Taskmato
//

import Foundation
import Observation

/// Coordinates one session-history import or export operation for the Settings UI.
@Observable
@MainActor
final class SessionPortabilityController {

  /// The user-visible phase of the current portability operation.
  enum State {
    /// No operation is running or awaiting confirmation.
    case idle
    /// A durable snapshot is being prepared for export.
    case preparingExport
    /// A validated document is ready for the system save panel.
    case readyToExport(SessionHistoryFile)
    /// A selected import file is being checked before mutation.
    case preflightingImport
    /// A validated import preview is ready for an explicit merge confirmation.
    case awaitingConfirmation(SessionHistoryImportPlan)
    /// The atomic repository merge is currently running.
    case importing
    /// The last operation successfully finished.
    case completed(SessionMergeResult)
    /// The last operation failed with an actionable message.
    case failed(String)
  }

  /// The normalized payload and local-history revision associated with an import preview.
  struct SessionHistoryImportPlan: Sendable {
    /// The decoded file retained without rereading it at confirmation.
    let payload: SessionImportPayload
    /// The previewed outcome counts and date range.
    let preview: SessionMergePreview
    /// The local history revision that produced the preview.
    let historyRevision: Int
  }

  /// The currently observable operation state.
  private(set) var state: State = .idle

  private let store: SessionStore
  private var operationTask: Task<Void, Never>?

  /// Creates a controller for one observable session-history store.
  /// - Parameter store: The app-wide session-history facade.
  init(store: SessionStore) { self.store = store }

  /// Starts export preparation after the user has accepted the privacy warning.
  func prepareExport() {
    guard operationTask == nil else { return }
    state = .preparingExport
    operationTask = Task { [weak self] in
      guard let self else { return }
      defer { operationTask = nil }
      do {
        let sessions = try await store.durableSnapshot()
        let document = try await Task.detached {
          try SessionPortability.makeDocument(sessions: sessions)
        }.value
        let data = try await Task.detached { try SessionPortability.encode(document) }.value
        state = .readyToExport(SessionHistoryFile(data: data))
      } catch {
        state = .failed(error.localizedDescription)
      }
    }
  }

  /// Reads, validates, and previews an import file without changing persisted history.
  /// - Parameter url: The user-selected security-scoped document URL.
  func preflightImport(from url: URL) {
    guard operationTask == nil else { return }
    state = .preflightingImport
    operationTask = Task { [weak self] in
      guard let self else { return }
      defer { operationTask = nil }
      do {
        let payload = try await Self.readPayload(from: url)
        let localSessions = try await store.durableSnapshot()
        state = .awaitingConfirmation(
          SessionHistoryImportPlan(
            payload: payload,
            preview: SessionPortability.preview(
              payload: payload, localSessions: localSessions),
            historyRevision: store.historyRevision))
      } catch {
        state = .failed(error.localizedDescription)
      }
    }
  }

  /// Rechecks the sampled history revision, then atomically merges the retained preview payload.
  func confirmImport() {
    guard operationTask == nil, case .awaitingConfirmation(let plan) = state else { return }
    operationTask = Task { [weak self] in
      guard let self else { return }
      defer { operationTask = nil }
      do {
        if store.historyRevision != plan.historyRevision {
          let localSessions = try await store.durableSnapshot()
          state = .awaitingConfirmation(
            SessionHistoryImportPlan(
              payload: plan.payload,
              preview: SessionPortability.preview(
                payload: plan.payload, localSessions: localSessions),
              historyRevision: store.historyRevision))
          return
        }
        state = .importing
        var result = try await store.mergeImportedAtomically(plan.payload.sessions)
        result.skipped += plan.payload.duplicateSkips
        state = .completed(result)
      } catch {
        state = .failed(error.localizedDescription)
      }
    }
  }

  /// Dismisses a completed, failed, or ready-to-export state back to idle.
  func dismiss() {
    guard operationTask == nil else { return }
    state = .idle
  }

  /// Waits for the currently scheduled portability operation to settle; used by deterministic tests.
  func waitForOperation() async {
    await operationTask?.value
  }

  /// Reads and validates selected bytes off the main actor, respecting sandbox file access.
  private nonisolated static func readPayload(from url: URL) async throws -> SessionImportPayload {
    try await Task.detached {
      let accessed = url.startAccessingSecurityScopedResource()
      defer {
        if accessed { url.stopAccessingSecurityScopedResource() }
      }
      let values = try url.resourceValues(forKeys: [.fileSizeKey])
      if let size = values.fileSize, size > SessionPortability.maximumFileBytes {
        throw SessionPortabilityError.fileTooLarge
      }
      let data = try Data(contentsOf: url)
      return try SessionPortability.decodeAndNormalize(data)
    }.value
  }
}
