//
//  SwiftDataSessionRepository.swift
//  Taskmato
//

import Foundation
import SwiftData

/// A ``SessionRepository`` backed by a SwiftData store.
///
/// `@ModelActor` isolates the non-`Sendable` `ModelContext` to this actor's executor.
/// The production store is `~/Library/Application Support/Taskmato/Sessions.store`.
@ModelActor
actor SwiftDataSessionRepository: SessionRepository {

  private var preSaveHook: (@Sendable () throws -> Void)?

  /// Installs a test-only hook that runs immediately before the next repository save.
  /// - Parameter hook: A synchronous hook, or `nil` to restore normal saving.
  func setPreSaveHook(_ hook: (@Sendable () throws -> Void)?) {
    preSaveHook = hook
  }

  func sessions(over interval: DateInterval) throws -> [Session] {
    let start = interval.start
    let end = interval.end
    let descriptor = FetchDescriptor<SessionEntity>(
      predicate: #Predicate { $0.startedAt >= start && $0.startedAt <= end },
      sortBy: [SortDescriptor(\.startedAt, order: .forward)])
    return try modelContext.fetch(descriptor).map(Session.init(entity:))
  }

  func append(_ session: Session) throws {
    modelContext.insert(SessionEntity(session: session))
    try modelContext.save()
  }

  func upsert(_ session: Session) throws {
    let id = session.id
    let descriptor = FetchDescriptor<SessionEntity>(predicate: #Predicate { $0.id == id })
    if let existing = try modelContext.fetch(descriptor).first {
      existing.update(from: session)
    } else {
      modelContext.insert(SessionEntity(session: session))
    }
    try modelContext.save()
  }

  func mergeImportedAtomically(_ sessions: [Session]) throws -> SessionMergeResult {
    let descriptor = FetchDescriptor<SessionEntity>()
    let existing = try modelContext.fetch(descriptor)
    var localByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
    var result = SessionMergeResult()

    do {
      for session in sessions {
        guard let local = localByID[session.id] else {
          let entity = SessionEntity(session: session)
          modelContext.insert(entity)
          localByID[session.id] = entity
          result.inserted += 1
          continue
        }

        let localSession = Session(entity: local)
        if session.endedAt > localSession.endedAt {
          local.update(from: session)
          result.updated += 1
        } else if session.endedAt < localSession.endedAt {
          result.skipped += 1
        } else if session == localSession {
          result.skipped += 1
        } else {
          result.conflicts += 1
        }
      }
      try preSaveHook?()
      try modelContext.save()
      return result
    } catch {
      modelContext.rollback()
      throw error
    }
  }
}

extension SwiftDataSessionRepository {

  /// File name of the production SwiftData store.
  static let storeFileName = "Sessions.store"

  /// The default production store URL, creating the containing directory if needed.
  static func defaultStoreURL() -> URL {
    let appSupport = FileManager.default.urls(
      for: .applicationSupportDirectory, in: .userDomainMask
    ).first!
    let dir = appSupport.appendingPathComponent("Taskmato", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir.appendingPathComponent(storeFileName)
  }

  /// Builds a persistent container at `url`.
  static func makeContainer(url: URL) throws -> ModelContainer {
    let configuration = ModelConfiguration(url: url)
    return try ModelContainer(for: SessionEntity.self, configurations: configuration)
  }

  /// Builds an ephemeral in-memory container for tests and previews.
  static func makeInMemoryContainer() throws -> ModelContainer {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(for: SessionEntity.self, configurations: configuration)
  }

  /// A repository over a fresh in-memory container; the extractable fixture for tests and previews.
  static func makeInMemory() throws -> SwiftDataSessionRepository {
    SwiftDataSessionRepository(modelContainer: try makeInMemoryContainer())
  }
}
