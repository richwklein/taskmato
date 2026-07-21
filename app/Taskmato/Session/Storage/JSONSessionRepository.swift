//
//  JSONSessionRepository.swift
//  Taskmato
//

import Foundation
import os

/// A ``SessionRepository`` backed by a JSON array on disk.
///
/// The full log is held in memory and rewritten wholesale on every append. The production
/// path is `~/Library/Application Support/Taskmato/sessions.json`.
actor JSONSessionRepository: SessionRepository {

  /// All recorded sessions, ordered oldest-first. Authoritative in-memory cache.
  private var cache: [Session]

  private let fileURL: URL
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()
  private let logger = Logger(subsystem: "com.taskmato", category: "JSONSessionRepository")

  /// The default production file URL, creating the containing directory if needed.
  static func defaultFileURL() -> URL {
    let appSupport = FileManager.default.urls(
      for: .applicationSupportDirectory, in: .userDomainMask
    ).first!
    let dir = appSupport.appendingPathComponent("Taskmato", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir.appendingPathComponent("sessions.json")
  }

  /// Creates a repository backed by a specific file URL. Pass a temporary path in tests.
  init(fileURL: URL) {
    self.fileURL = fileURL
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    decoder.dateDecodingStrategy = .iso8601
    if let data = try? Data(contentsOf: fileURL) {
      cache = (try? decoder.decode([Session].self, from: data)) ?? []
    } else {
      cache = []
    }
  }

  func sessions(over interval: DateInterval) -> [Session] {
    cache.filter { interval.contains($0.startedAt) }
  }

  func append(_ session: Session) throws {
    cache.append(session)
    let data = try encoder.encode(cache)
    try data.write(to: fileURL, options: .atomic)
  }
}
