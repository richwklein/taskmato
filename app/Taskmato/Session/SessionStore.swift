//
//  SessionStore.swift
//  Taskmato
//

import Foundation
import Observation

/// Persists and provides access to the log of completed Pomodoro sessions.
///
/// Sessions are stored as a JSON array at the path passed to `init(fileURL:)`.
/// The production path is `~/Library/Application Support/Taskmato/sessions.json`.
@Observable
final class SessionStore {

  /// All recorded sessions, ordered oldest-first.
  private(set) var sessions: [Session] = []

  private let fileURL: URL
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  /// Creates a store using the default production file path.
  convenience init() {
    let appSupport = FileManager.default.urls(
      for: .applicationSupportDirectory, in: .userDomainMask
    ).first!
    let dir = appSupport.appendingPathComponent("Taskmato", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    self.init(fileURL: dir.appendingPathComponent("sessions.json"))
  }

  /// Creates a store using a specific file URL. Pass a temporary path in tests.
  init(fileURL: URL) {
    self.fileURL = fileURL
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    decoder.dateDecodingStrategy = .iso8601
    load()
  }

  /// Appends a session record to the log and writes it to disk.
  func append(_ session: Session) {
    sessions.append(session)
    save()
  }

  /// Number of completed focus sessions that started today (calendar day, local time zone).
  func todayFocusCount() -> Int {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    return sessions.filter {
      $0.phase == .focus && $0.wasCompleted && calendar.startOfDay(for: $0.startedAt) == today
    }.count
  }

  /// Total elapsed minutes across all completed focus sessions that started today.
  func todayFocusMinutes() -> Int {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let total = sessions.filter {
      $0.phase == .focus && $0.wasCompleted && calendar.startOfDay(for: $0.startedAt) == today
    }.reduce(0) { $0 + $1.duration }
    return Int(total / 60)
  }

  // MARK: - Private

  private func load() {
    guard let data = try? Data(contentsOf: fileURL) else { return }
    sessions = (try? decoder.decode([Session].self, from: data)) ?? []
  }

  private func save() {
    guard let data = try? encoder.encode(sessions) else { return }
    try? data.write(to: fileURL, options: .atomic)
  }
}
